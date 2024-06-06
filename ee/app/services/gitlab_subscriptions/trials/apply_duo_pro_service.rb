# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyDuoProService < ::GitlabSubscriptions::Trials::BaseApplyTrialService
      def valid_to_generate_trial?
        namespace.present? && namespace.paid? && namespace.subscription_add_on_purchases.for_gitlab_duo_pro.none?
      end

      private

      def execute_trial_request
        client.generate_addon_trial(uid: uid, trial_user: trial_user_information)
      end
    end
  end
end
