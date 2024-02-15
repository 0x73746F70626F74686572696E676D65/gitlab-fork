# frozen_string_literal: true

require 'open3'

module Backup
  module Targets
    class Files < Target
      extend ::Gitlab::Utils::Override
      include Backup::Helper

      DEFAULT_EXCLUDE = ['lost+found'].freeze

      # Use the content from a PIPE instead of an actual filepath (used by tar as input or output)
      USE_PIPE_INSTEAD_OF_FILE = '-'

      attr_reader :excludes

      def initialize(progress, storage_path, options:, excludes: [])
        super(progress, options: options)

        @storage_path = storage_path
        @excludes = excludes
      end

      # Copy files from public/files to backup/files
      override :dump

      def dump(backup_tarball, _)
        FileUtils.mkdir_p(backup_basepath)
        FileUtils.rm_f(backup_tarball)

        tar_utils = ::Gitlab::Backup::Cli::Utils::Tar.new
        shell_pipeline = ::Gitlab::Backup::Cli::Shell::Pipeline
        compress_command = ::Gitlab::Backup::Cli::Shell::Command.new(compress_cmd)

        if options.strategy == ::Backup::Options::Strategy::COPY
          cmd = [%w[rsync -a --delete], exclude_dirs_rsync, %W[#{storage_realpath} #{backup_basepath}]].flatten
          output, status = Gitlab::Popen.popen(cmd)

          # Retry if rsync source files vanish
          if status == 24
            $stdout.puts "Warning: files vanished during rsync, retrying..."
            output, status = Gitlab::Popen.popen(cmd)
          end

          unless status == 0
            puts output
            raise_custom_error(backup_tarball)
          end

          archive_file = [backup_tarball, 'w', 0o600]
          tar_command = tar_utils.pack_cmd(
            archive_file: USE_PIPE_INSTEAD_OF_FILE,
            target_directory: backup_files_realpath,
            target: '.',
            excludes: excludes)
          result = shell_pipeline.new(tar_command, compress_command).run_pipeline!(output: archive_file)

          FileUtils.rm_rf(backup_files_realpath)
        else
          archive_file = [backup_tarball, 'w', 0o600]
          tar_command = tar_utils.pack_cmd(
            archive_file: USE_PIPE_INSTEAD_OF_FILE,
            target_directory: storage_realpath,
            target: '.',
            excludes: excludes)

          result = shell_pipeline.new(tar_command, compress_command).run_pipeline!(output: archive_file)
        end

        success = pipeline_succeeded?(
          tar_status: result.status_list[0],
          compress_status: result.status_list[1],
          output: result.stderr)

        raise_custom_error(backup_tarball) unless success
      end

      override :restore

      def restore(backup_tarball, _)
        backup_existing_files_dir(backup_tarball)

        cmd_list = [decompress_cmd, %W[#{tar} --unlink-first --recursive-unlink -C #{storage_realpath} -xf -]]
        status_list, output = run_pipeline!(cmd_list, in: backup_tarball.to_s)
        success = pipeline_succeeded?(compress_status: status_list[0], tar_status: status_list[1], output: output)

        raise Backup::Error, "Restore operation failed: #{output}" unless success
      end

      def tar
        if system(*%w[gtar --version], out: '/dev/null')
          # It looks like we can get GNU tar by running 'gtar'
          'gtar'
        else
          'tar'
        end
      end

      def backup_existing_files_dir(backup_tarball)
        name = File.basename(backup_tarball, '.tar.gz')
        timestamped_files_path = backup_basepath.join('tmp', "#{name}.#{Time.now.to_i}")

        return unless File.exist?(storage_realpath)

        # Move all files in the existing repos directory except . and .. to
        # repositories.<timestamp> directory
        FileUtils.mkdir_p(timestamped_files_path, mode: 0o700)

        dot_references = [File.join(storage_realpath, "."), File.join(storage_realpath, "..")]
        matching_files = Dir.glob(File.join(storage_realpath, "*"), File::FNM_DOTMATCH)
        files = matching_files - dot_references

        FileUtils.mv(files, timestamped_files_path)
      rescue Errno::EACCES
        access_denied_error(storage_realpath)
      rescue Errno::EBUSY
        resource_busy_error(storage_realpath)
      end

      def run_pipeline!(cmd_list, options = {})
        err_r, err_w = IO.pipe
        options[:err] = err_w
        status_list = Open3.pipeline(*cmd_list, options)
        err_w.close

        [status_list, err_r.read]
      end

      def noncritical_warning?(warning)
        noncritical_warnings = [
          /^g?tar: \.: Cannot mkdir: No such file or directory$/
        ]

        noncritical_warnings.map { |w| warning =~ w }.any?
      end

      def pipeline_succeeded?(tar_status:, compress_status:, output:)
        return false unless compress_status&.success?

        tar_status&.success? || tar_ignore_non_success?(tar_status.exitstatus, output)
      end

      def tar_ignore_non_success?(exitstatus, output)
        # tar can exit with nonzero code:
        #  1 - if some files changed (i.e. a CI job is currently writes to log)
        #  2 - if it cannot create `.` directory (see issue https://gitlab.com/gitlab-org/gitlab/-/issues/22442)
        #  http://www.gnu.org/software/tar/manual/html_section/tar_19.html#Synopsis
        #  so check tar status 1 or stderr output against some non-critical warnings
        if exitstatus == 1
          $stdout.puts "Ignoring tar exit status 1 'Some files differ': #{output}"
          return true
        end

        # allow tar to fail with other non-success status if output contain non-critical warning
        if noncritical_warning?(output)
          $stdout.puts(
            "Ignoring non-success exit status #{exitstatus} due to output of non-critical warning(s): #{output}")
          return true
        end

        false
      end

      def exclude_dirs_rsync
        default = DEFAULT_EXCLUDE.map { |entry| "--exclude=#{entry}" }

        basepath = Pathname(File.basename(storage_realpath))

        default.concat(excludes.map { |entry| "--exclude=/#{basepath.join(entry)}" })
      end

      def raise_custom_error(backup_tarball)
        raise FileBackupError.new(storage_realpath, backup_tarball)
      end

      private

      def storage_realpath
        @storage_realpath ||= File.realpath(@storage_path)
      end

      def backup_files_realpath
        @backup_files_realpath ||= backup_basepath.join(File.basename(@storage_path))
      end

      def backup_basepath
        Pathname(Gitlab.config.backup.path)
      end
    end
  end
end
