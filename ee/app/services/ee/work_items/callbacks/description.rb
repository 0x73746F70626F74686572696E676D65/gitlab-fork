# frozen_string_literal: true

module EE
  module WorkItems
    module Callbacks
      module Description
        extend ::Gitlab::Utils::Override

        override :after_initialize
        def after_initialize
          super

          return unless update_description?

          synced_epic_params[:description] = params[:description]
          synced_epic_params[:description_html] = work_item.description_html
        end
      end
    end
  end
end
