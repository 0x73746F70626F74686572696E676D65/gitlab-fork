# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Metadata
        autoload :Serializer, 'gitlab/backup/cli/metadata/serializer'
        autoload :Deserializer, 'gitlab/backup/cli/metadata/deserializer'
      end
    end
  end
end
