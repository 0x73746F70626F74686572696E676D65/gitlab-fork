# frozen_string_literal: true

module Gitlab
  module Cleanup
    module OrphanJobArtifactFinalObjects
      class BatchFromList
        include StorageHelpers

        def initialize(entries, logger: Gitlab::AppLogger)
          @entries = entries
          @logger = logger
        end

        def orphan_objects
          objects = {}

          each_fog_file do |fog_file|
            objects[path_without_bucket_prefix(fog_file.key)] = fog_file
          end

          return [] unless objects.any?

          # During the process of identifying orphan objects, there might be a very
          # tiny window for a race condition. This happens between checking for existence of
          # job artifact DB record, and the checking of pending direct upload entry in redis.
          # It may be possible that a pending direct upload completes (creates DB record and
          # deletes redis entry) only right after the script had already checked for the matching
          # job artifact record and not finding one, but right before the script checks for a
          # pending upload entry, thus the script finding no redis entry anymore, which would
          # lead to a false positive orphan object.
          #
          # This is why for sanity check, we still want to make sure that there is no matching
          # job artifact record in the database before we delete the object.
          paths_with_job_artifact_records(objects.keys).each do |non_orphan_path|
            log_skipping_object(non_orphan_path)
            objects.delete(non_orphan_path)
          end

          return [] unless objects.any?

          # Just to keep the lexicographic order of objects
          objects.values.sort_by(&:key)
        end

        private

        attr_reader :entries, :logger

        def each_fog_file
          entries.each do |entry|
            yield build_fog_file(entry)
          end
        end

        def build_fog_file(line)
          # NOTE: If the object store is configured to use bucket prefix, the GenerateList task would have included the
          # bucket_prefix in paths in the orphans list CSV.
          path_with_bucket_prefix, size = line.split(',')
          artifacts_directory.files.new(key: path_with_bucket_prefix, content_length: size)
        end

        def path_without_bucket_prefix(path)
          # `path` contains the fog file's key. It is the object path relative to the artifacts bucket, for example:
          # aa/bb/abc123/@final/12/34/def12345
          #
          # But if the instance is configured to only use a single bucket combined with bucket prefixes,
          # for example if the `bucket_prefix` is "my/artifacts", the `path` would then look like:
          # my/artifacts/aa/bb/abc123/@final/12/34/def12345
          #
          # To correctly identify orphan objects, we need to strip the bucket_prefix
          # off of the `path` because we need this to match the correct job artifact record by
          # its `file_final_path` column which contains the object's path without `bucket_prefix`.
          #
          # If bucket_prefix is not present, this will just return the original path.
          Pathname.new(path).relative_path_from(bucket_prefix.to_s).to_s
        end

        def paths_with_job_artifact_records(paths)
          ::Ci::JobArtifact.where(file_final_path: paths).pluck(:file_final_path) # rubocop:disable CodeReuse/ActiveRecord -- intentionally used pluck directly to keep it simple.
        end

        def log_skipping_object(path)
          logger.info("Found job artifact record for object #{path}, skipping.")
        end
      end
    end
  end
end
