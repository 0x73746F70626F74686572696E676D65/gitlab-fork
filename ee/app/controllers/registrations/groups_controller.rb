# frozen_string_literal: true

module Registrations
  class GroupsController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include ::Onboarding::SetRedirect

    skip_before_action :set_confirm_warning
    before_action :verify_onboarding_enabled!
    before_action :authorize_create_group!, only: :new

    before_action do
      experiment(:project_templates_during_registration, user: current_user).publish
    end

    layout 'minimal'

    feature_category :onboarding

    urgency :low, [:create]

    def new
      @group = Group.new(visibility_level: Gitlab::CurrentSettings.default_group_visibility)
      @project = Project.new(namespace: @group)
      @template_name = ''
      @initialize_with_readme = true

      experiment(:project_templates_during_registration, user: current_user)
        .track(:render_groups_new, label: onboarding_status.tracking_label)

      track_event('view_new_group_action')
    end

    def create
      service_class = if import?
                        Registrations::ImportNamespaceCreateService
                      else
                        Registrations::StandardNamespaceCreateService
                      end

      service_params = params.with_defaults(organization_id: Current.organization_id)
      result = service_class.new(current_user, service_params).execute

      if result.success?
        actions_after_success(result.payload)
      else
        @group = result.payload[:group]
        @project = result.payload[:project]
        @template_name = params.dig(:project, :template_name)
        @initialize_with_readme = params.dig(:project, :initialize_with_readme)

        render :new
      end
    end

    private

    def actions_after_success(payload)
      ::Onboarding::FinishService.new(current_user).execute

      if import?
        import_url = URI.join(root_url, params[:import_url], "?namespace_id=#{payload[:group].id}").to_s
        redirect_to import_url
      else
        track_project_registration_submission(payload[:project])

        cookies[:confetti_post_signup] = true

        redirect_to project_learn_gitlab_path(payload[:project])
      end
    end

    def authorize_create_group!
      access_denied! unless can?(current_user, :create_group)
    end

    def import?
      params[:import_url].present?
    end

    def track_event(action)
      ::Gitlab::Tracking
        .event(self.class.name, action, user: current_user, label: onboarding_status.tracking_label)
    end

    def track_project_registration_submission(project)
      experiment_project_templates_during_registration(
        project,
        :successfully_submitted_form,
        onboarding_status.tracking_label
      )

      template_name = params.dig(:project, :template_name)
      return if template_name.blank?

      experiment_project_templates_during_registration(
        project,
        "select_project_template_#{template_name}",
        onboarding_status.tracking_label
      )
    end

    def experiment_project_templates_during_registration(project, name, label)
      experiment(
        :project_templates_during_registration,
        user: current_user,
        project: project,
        namespace: project.namespace
      ).track(name, label: label)
    end

    def onboarding_status
      ::Onboarding::Status.new(params, session, current_user)
    end
    strong_memoize_attr :onboarding_status
  end
end
