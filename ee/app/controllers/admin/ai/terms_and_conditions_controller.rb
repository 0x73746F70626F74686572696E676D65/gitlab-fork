# frozen_string_literal: true

module Admin
  module Ai
    class TermsAndConditionsController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :custom_models
      urgency :low

      before_action :ensure_feature_enabled!

      def index
        redirect_to admin_ai_self_hosted_models_url if ::Ai::TestingTermsAcceptance.has_accepted?
      end

      def create
        ::Ai::TestingTermsAcceptance.create!(user_id: current_user.id, user_email: current_user.email)

        redirect_to admin_ai_self_hosted_models_url, notice: _("Successfully accepted GitLab Testing Terms")
      end

      private

      def ensure_feature_enabled!
        render_404 unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
        render_404 unless Ability.allowed?(current_user, :manage_ai_settings)
      end
    end
  end
end
