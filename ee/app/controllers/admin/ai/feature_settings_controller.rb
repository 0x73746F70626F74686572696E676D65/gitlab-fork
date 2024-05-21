# frozen_string_literal: true

module Admin
  module Ai
    class FeatureSettingsController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      feature_category :custom_models
      urgency :low

      before_action :ensure_feature_enabled!

      def index
        feature_settings_by_name = ::Ai::FeatureSetting.all.index_by(&:feature)

        @feature_settings = ::Ai::FeatureSetting.features.keys.map do |feature|
          feature_settings_by_name[feature] || ::Ai::FeatureSetting.new(feature: feature)
        end
      end

      # rubocop:disable CodeReuse/ActiveRecord -- Using find_or_initialize_by is reasonable
      def edit
        @feature_setting = ::Ai::FeatureSetting.find_or_initialize_by(feature: params[:id])
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def create
        @feature_setting = ::Ai::FeatureSetting.create(feature_settings_params)

        if @feature_setting.persisted?
          redirect_to admin_ai_feature_settings_url, notice: _("Feature settings updated successfully")
        else
          render :edit
        end
      end

      def update
        @feature_setting = ::Ai::FeatureSetting.find(params[:id])

        if @feature_setting.update(feature_settings_params)
          redirect_to admin_ai_feature_settings_url, notice: _("Feature settings updated successfully")
        else
          render :edit
        end
      end

      private

      def feature_settings_params
        params.require(:feature_setting).permit(
          :feature, :provider, :ai_self_hosted_model_id
        )
      end

      def ensure_feature_enabled!
        render_404 unless feature_available?
      end

      def feature_available?
        return false if gitlab_com_subscription?
        return false unless License.current&.paid? && gitlab_duo_available?
        return false unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

        true
      end
    end
  end
end
