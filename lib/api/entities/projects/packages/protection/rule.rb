# frozen_string_literal: true

module API
  module Entities
    module Projects
      module Packages
        module Protection
          class Rule < Grape::Entity
            expose :id, documentation: { type: 'integer', example: 1 }
            expose :project_id, documentation: { type: 'integer', example: 1 }
            expose :package_name_pattern, documentation: { type: 'string', example: 'flightjs/flight' }
            expose :package_type, documentation: { type: 'string', example: 'npm' }
            expose :push_protected_up_to_access_level, documentation: { type: 'string', example: 'maintainer' }
          end
        end
      end
    end
  end
end
