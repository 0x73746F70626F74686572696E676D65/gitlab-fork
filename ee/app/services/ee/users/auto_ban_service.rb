# frozen_string_literal: true

module EE
  module Users
    module AutoBanService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        send_truth_data

        super
      end

      private

      def send_truth_data
        return unless ::Feature.enabled?(:arkose_truth_data_auto_ban, user, type: :gitlab_com_derisk)

        Arkose::TruthDataService.new(user: user, is_legit: false).execute
      end
    end
  end
end
