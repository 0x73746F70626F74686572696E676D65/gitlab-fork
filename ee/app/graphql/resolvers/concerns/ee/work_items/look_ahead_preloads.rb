# frozen_string_literal: true

module EE
  module WorkItems
    module LookAheadPreloads
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :widget_preloads
      def widget_preloads
        super.merge(
          status: { requirement: :recent_test_reports },
          progress: :progress,
          test_reports: :test_reports,
          feature_flags: { feature_flags: :project }
        )
      end

      def unconditional_includes
        [
          *super,
          :sync_object
        ]
      end
    end
  end
end
