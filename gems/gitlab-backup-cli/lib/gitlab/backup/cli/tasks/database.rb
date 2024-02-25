# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Tasks
        class Database < Task
          def self.id = 'db'

          def human_name = _('database')

          def destination_path = 'db'

          def cleanup_path = 'db'

          private

          def target
            ::Backup::Targets::Database.new(output, options: options)
          end
        end
      end
    end
  end
end
