# frozen_string_literal: true

module Admin
  module Ai
    class SelfHostedModelsController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :custom_models
      urgency :low

      before_action :ensure_registration!
      before_action :ensure_feature_enabled!

      def index
        @self_hosted_models = ::Ai::SelfHostedModel.all
        @custom_models_json = @self_hosted_models.to_json(only: [:id, :name, :model, :api_token, :endpoint])
      end

      def new
        @self_hosted_model = ::Ai::SelfHostedModel.new
      end

      def create
        @self_hosted_model = ::Ai::SelfHostedModel.create(self_hosted_models_params)

        if @self_hosted_model.persisted?
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was created")
        else
          render :new
        end
      end

      def edit
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])
      end

      def update
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])

        if @self_hosted_model.update(self_hosted_models_params)
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was updated")
        else
          render :edit
        end
      end

      def destroy
        @self_hosted_model = ::Ai::SelfHostedModel.find(params[:id])

        if @self_hosted_model.destroy
          redirect_to admin_ai_self_hosted_models_url, notice: _("Self-Hosted Model was deleted")
        else
          render :index
        end
      end

      private

      def ensure_registration!
        return if ::Ai::TestingTermsAcceptance.has_accepted?

        redirect_to admin_ai_terms_and_conditions_url
      end

      def self_hosted_models_params
        params.require(:self_hosted_model).permit(:name, :model, :endpoint, :api_token)
      end

      def ensure_feature_enabled!
        render_404 unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
        render_404 unless Ability.allowed?(current_user, :manage_ai_settings)
      end
    end
  end
end
