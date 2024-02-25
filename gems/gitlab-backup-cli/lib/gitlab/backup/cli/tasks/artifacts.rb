# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Tasks
        class Artifacts < Task
          def self.id = 'artifacts'

          def human_name = _('artifacts')

          def destination_path = 'artifacts.tar.gz'

          private

          def target
            ::Backup::Targets::Files.new(nil, storage_path, options: options, excludes: ['tmp'])
          end

          def storage_path
            # TODO: Use configuration solver
            JobArtifactUploader.root
          end
        end
      end
    end
  end
end
