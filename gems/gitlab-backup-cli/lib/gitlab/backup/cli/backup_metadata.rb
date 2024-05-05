# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      # Backup Metadata includes information about the Backup
      class BackupMetadata
        extend Utils::MetadataSerialization
        include Utils::MetadataSerialization

        # Metadata version number should always increase when:
        # - field is added
        # - field is removed
        # - field format/type changes
        METADATA_VERSION = 2

        # Metadata filename used when writing or loading from a filesystem location
        METADATA_FILENAME = 'backup_information.json'

        # Metadata file permissions
        METADATA_FILE_MODE = 0o600

        # List all of the current top level fields along with their expected data
        # type name to specify how to parse and serialize values
        CURRENT_FIELD_DEFINITIONS = {
          backup_id: :string,
          created_at: :time,
          gitlab_version: :string,
          metadata_version: :integer
        }.freeze

        # Unique ID for a backup
        # @return [String]
        attr_reader :backup_id

        # Timestamp when the backup was created
        # @return [Time]
        attr_reader :created_at

        # Gitlab Version in which the backup was created
        # @return [String]
        attr_reader :gitlab_version

        # Integer representing the increment of metadata version
        # this data was saved with
        # @return [Integer]
        attr_reader :metadata_version

        def initialize(
          created_at:,
          backup_id:,
          gitlab_version:,
          metadata_version: METADATA_VERSION
        )
          @created_at = created_at
          @backup_id = backup_id
          @gitlab_version = gitlab_version
          @metadata_version = metadata_version
        end

        # Returns the expected metadata file path inside directory +backup_directory+
        #
        # @param [String|Pathname] backup_directory
        # @return [Pathname]
        def self.path_in_backup_directory(backup_directory)
          Pathname(backup_directory).join(METADATA_FILENAME)
        end

        # Build a new BackupMetadata with defaults
        #
        # @param [String] gitlab_version
        def self.build(gitlab_version:)
          created_at = Time.current
          backup_id = "#{created_at.strftime('%s_%Y_%m_%d_')}#{gitlab_version}"

          new(
            backup_id: backup_id,
            created_at: created_at,
            gitlab_version: gitlab_version,
            metadata_version: METADATA_VERSION
          )
        end

        # Load the metadata stored in the given JSON file path
        #
        # @param [String] metadata_json_file
        # @return [Gitlab::Backup::Cli::BackupMetadata]
        def self.read(metadata_json_file)
          # should be a hash of string keys mapped to various JSON primitives
          saved_data_hash = JSON.parse(File.read(metadata_json_file.to_path))

          parsed_fields = {}
          CURRENT_FIELD_DEFINITIONS.each do |key, data_type|
            stored_value = saved_data_hash[key.to_s]
            parsed_value = parse_value(type: data_type, value: stored_value)
            parsed_fields[key] = parsed_value
          end

          new(**parsed_fields)
        rescue IOError, Errno::ENOENT => error
          Gitlab::Backup::Cli::Output.error(
            "Failed to write backup information to: #{metadata_json_file} (#{error.message})"
          )

          nil
        end

        def self.read_from_backup_directory(backup_directory)
          read(path_in_backup_directory(backup_directory))
        end

        # Expose the information that will be part of the Metadata JSON file
        def to_hash
          CURRENT_FIELD_DEFINITIONS.each_with_object({}) do |(key, type), hash|
            # fetch attribute value dynamically
            value = self.send(key)
            serialized_value = serialize_value(type: type, value: value)
            hash[key] = serialized_value
          end
        end

        def write!(basepath)
          basepath = Pathname(basepath) unless basepath.is_a? Pathname

          json_file = self.class.path_in_backup_directory(basepath)
          json = JSON.pretty_generate(to_hash)

          json_file.open(File::RDWR | File::CREAT, METADATA_FILE_MODE) do |file|
            file.write(json)
          end

          true
        rescue IOError, Errno::ENOENT => e
          Gitlab::Backup::Cli::Output.error("Failed to Backup information to: #{json_file} (#{e.message})")

          false
        end
      end
    end
  end
end
