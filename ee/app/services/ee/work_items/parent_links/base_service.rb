# frozen_string_literal: true

module EE
  module WorkItems
    module ParentLinks
      module BaseService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def initialize(issuable, user, params)
          @synced_work_item = params.delete(:synced_work_item)

          super
        end

        private

        attr_reader :synced_work_item
      end
    end
  end
end
