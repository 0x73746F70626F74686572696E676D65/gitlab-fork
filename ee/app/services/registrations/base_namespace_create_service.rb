# frozen_string_literal: true

module Registrations
  class BaseNamespaceCreateService
    include BaseServiceUtility
    include Gitlab::Experiment::Dsl

    def initialize(user, params = {})
      @user = user
      @params = params.dup
    end

    private

    attr_reader :user, :params, :project, :group

    def after_successful_group_creation(group_track_action:)
      ::Groups::CreateEventWorker.perform_async(group.id, user.id, :created)
      Gitlab::Tracking.event(self.class.name, group_track_action, namespace: group, user: user)
      ::Onboarding::Progress.onboard(group)

      experiment(:phone_verification_for_low_risk_users, user: user).track(:assignment, namespace: group)
      experiment(:signup_intent_step_one, actor: user).track(:assignment, namespace: group)

      # TODO: As the next step in https://gitlab.com/gitlab-org/gitlab/-/issues/435745, we can merely call
      # a variation of the user.onboarding_status_initial_registration_type == REGISTRATION_TYPE[:trial]
      # (initial_trial?) here.
      if onboarding_status.trial_from_the_beginning?
        experiment(:trial_discover_page, actor: user).track(:assignment, namespace: group)
      end

      # TODO: As the next step in https://gitlab.com/gitlab-org/gitlab/-/issues/435745, we can merely call
      # a variation of the user.onboarding_status_registration_type == REGISTRATION_TYPE[:trial] (trial?) here.
      apply_trial if onboarding_status.trial_onboarding_flow?
    end

    def modified_group_params
      return group_params unless group_needs_path_added?

      group_params.compact_blank.with_defaults(path: Namespace.clean_path(group_name))
    end

    def apply_trial
      trial_user_information = glm_params.merge(namespace_id: group.id, gitlab_com_trial: true, sync_to_gl: true)
      trial_user_information[:namespace] = group.slice(:id, :name, :path, :kind, :trial_ends_on)

      GitlabSubscriptions::Trials::ApplyTrialWorker.perform_async(user.id, trial_user_information.to_h)
    end

    def glm_params
      params.permit(:glm_source, :glm_content)
    end

    def group_needs_path_added?
      group_name.present? && group_path.blank?
    end

    def group_name
      params.dig(:group, :name)
    end

    def group_path
      params.dig(:group, :path)
    end

    def group_params
      params.require(:group).permit(
        :name,
        :path,
        :visibility_level
      ).merge(setup_for_company: user.setup_for_company)
    end

    def onboarding_status
      @onboarding_status ||= ::Onboarding::Status.new(params, nil, user)
    end
  end
end
