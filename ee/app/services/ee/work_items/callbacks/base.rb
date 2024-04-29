# frozen_string_literal: true

module EE
  module WorkItems
    module Callbacks
      module Base
        extend ::Gitlab::Utils::Override

        def synced_epic_params
          @synced_epic_params ||= {}
        end
      end
    end
  end
end
