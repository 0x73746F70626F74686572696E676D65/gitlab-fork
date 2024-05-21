# frozen_string_literal: true

module EE
  module WorkItems
    module CreateService
      extend ::Gitlab::Utils::Override
      include ::WorkItems::SyncAsEpic

      private

      attr_reader :widget_params, :callbacks

      override :transaction_create
      def transaction_create(work_item)
        return super unless work_item.epic_work_item?

        super.tap do |save_result|
          break save_result unless save_result

          create_epic_for!(work_item)
        end
      end
    end
  end
end
