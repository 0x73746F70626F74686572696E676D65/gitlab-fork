# frozen_string_literal: true

module EE
  module Ci
    module JobsHelper
      extend ::Gitlab::Utils::Override

      override :jobs_data
      def jobs_data(project, build)
        super.merge({
          "subscriptions_more_minutes_url" => ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url,
          "ai_root_cause_analysis_available" => ::Llm::AnalyzeCiJobFailureService.new(current_user, build).valid?.to_s,
          "duo_features_enabled" => project.duo_features_enabled.to_s
        })
      end
    end
  end
end
