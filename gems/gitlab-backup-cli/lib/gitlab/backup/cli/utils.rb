# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Utils
        autoload :MetadataSerialization, 'gitlab/backup/cli/utils/metadata_serialization'
        autoload :PgDump, 'gitlab/backup/cli/utils/pg_dump'
        autoload :Tar, 'gitlab/backup/cli/utils/tar'
      end
    end
  end
end
