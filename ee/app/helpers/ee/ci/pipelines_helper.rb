# frozen_string_literal: true

module EE
  module Ci
    module PipelinesHelper
      extend ::Gitlab::Utils::Override

      def show_cc_validation_alert?(pipeline)
        return false unless ::Gitlab.com?
        return false if pipeline.user.blank? || current_user != pipeline.user

        pipeline.user_not_verified? && !pipeline.user.has_required_credit_card_to_run_pipelines?(pipeline.project)
      end

      override :pipelines_list_data
      def pipelines_list_data(project, list_url)
        super.merge(
          identity_verification_required: false.to_s,
          identity_verification_path: '#'
        )
      end
    end
  end
end
