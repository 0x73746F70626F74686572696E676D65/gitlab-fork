# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  module Trials
    class DuoProController < ApplicationController
      include OneTrustCSP
      include GoogleAnalyticsCSP
      include RegistrationsTracking
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper

      layout 'minimal'

      skip_before_action :set_confirm_warning

      before_action :check_feature_available!
      before_action :check_trial_eligibility!

      feature_category :subscription_management
      urgency :low

      def new
        if params[:step] == GitlabSubscriptions::Trials::CreateDuoProService::TRIAL
          track_event('render_duo_pro_trial_page')

          render :step_namespace
        else
          track_event('render_duo_pro_lead_page')

          render :step_lead
        end
      end

      def create
        @result = GitlabSubscriptions::Trials::CreateDuoProService.new(
          step: params[:step], lead_params: lead_params, trial_params: trial_params, user: current_user
        ).execute

        if @result.success?
          # lead and trial created
          flash[:success] = success_flash_message

          redirect_to group_usage_quotas_path(@result.payload[:namespace], anchor: 'code-suggestions-usage-tab')
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NO_SINGLE_NAMESPACE
          # lead created, but we now need to select namespace and then apply a trial
          redirect_to new_trials_duo_pro_path(@result.payload[:trial_selection_params])
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::NOT_FOUND
          # namespace not found/not permitted to create
          render_404
        elsif @result.reason == GitlabSubscriptions::Trials::CreateDuoProService::LEAD_FAILED
          render :step_lead_failed
        else
          # trial creation failed
          params[:namespace_id] = @result.payload[:namespace_id]

          render :trial_failed
        end
      end

      private

      def eligible_namespaces
        @eligible_namespaces = Users::DuoProTrialEligibleNamespacesFinder.new(current_user).execute
      end
      strong_memoize_attr :eligible_namespaces

      def check_feature_available!
        return if ::Gitlab::Saas.feature_available?(:subscriptions_trials)

        render_404
      end

      def check_trial_eligibility!
        return if eligible_namespaces_exist?

        render :access_denied, layout: 'errors', status: :forbidden
      end

      def eligible_namespaces_exist?
        return false if eligible_namespaces.none?

        GitlabSubscriptions::Trials::DuoPro.eligible_namespace?(params[:namespace_id], eligible_namespaces)
      end

      def namespace
        current_user.owned_groups.find_by_id(params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def track_event(action)
        Gitlab::InternalEvents.track_event(action, user: current_user, namespace: namespace)
      end

      def lead_params
        params.permit(
          :company_name, :company_size, :first_name, :last_name, :phone_number,
          :country, :state, :website_url, :glm_content, :glm_source
        ).to_h
      end

      def trial_params
        params.permit(:new_group_name, :namespace_id, :trial_entity, :glm_source, :glm_content)
        .with_defaults(organization_id: Current.organization_id).to_h
      end

      def success_flash_message
        safe_format(
          s_(
            'DuoProTrial|You have successfully created a trial subscription for GitLab Duo Pro. ' \
            'It will expire on %{exp_date}.%{new_line}To get started, enable the GitLab Duo Pro ' \
            'add-on for team members on this page by turning on the toggle for each team member. ' \
            "The subscription may take a minute to sync, so refresh the page if it's not visible yet."
          ),
          exp_date: GitlabSubscriptions::Trials::DuoPro::DURATION.from_now.strftime('%Y-%m-%d'),
          new_line: helpers.tag.br
        )
      end
    end
  end
end
