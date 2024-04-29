# frozen_string_literal: true

module EE
  module WorkItems
    module Callbacks
      module StartAndDueDate
        extend ::Gitlab::Utils::Override

        override :before_update
        def before_update
          super
          return unless update_start_and_due_date?

          synced_epic_params[:start_date] = params[:start_date]
          synced_epic_params[:due_date] = params[:due_date]
        end
      end
    end
  end
end
