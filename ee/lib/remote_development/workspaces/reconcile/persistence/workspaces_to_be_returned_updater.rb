# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Persistence
        class WorkspacesToBeReturnedUpdater
          # @param [Hash] context
          # @return [Hash]
          def self.update(context)
            context => {
              agent: agent, # Skip type checking to avoid coupling to Rails monolith
              workspaces_to_be_returned: Array => workspaces_to_be_returned,
            }

            # Update the responded_to_agent_at at this point, after we have already done all the calculations
            # related to state. Do it as a single query, so that they will all have the same timestamp.

            workspaces_to_be_returned_ids = workspaces_to_be_returned.map(&:id)

            agent.workspaces.where(id: workspaces_to_be_returned_ids).touch_all(:responded_to_agent_at) # rubocop:todo CodeReuse/ActiveRecord -- Use a finder class here
            agent.workspaces.where(id: workspaces_to_be_returned_ids, force_include_all_resources: true).update_all(force_include_all_resources: false) # rubocop:todo CodeReuse/ActiveRecord -- Use a finder class here
            context
          end
        end
      end
    end
  end
end
