# frozen_string_literal: true

module TrialsHelper
  TRIAL_ONBOARDING_SOURCE_URLS = %w[about.gitlab.com docs.gitlab.com learn.gitlab.com].freeze

  def create_lead_form_data
    _lead_form_data.merge(
      submit_path: trials_path(
        step: GitlabSubscriptions::Trials::CreateService::LEAD, **params.permit(:namespace_id).merge(glm_params)
      )
    )
  end

  def create_duo_pro_lead_form_data
    _lead_form_data.merge(
      submit_path: trials_duo_pro_path(
        step: GitlabSubscriptions::Trials::CreateDuoProService::LEAD,
        namespace_id: params[:namespace_id]
      )
    )
  end

  def create_company_form_data
    submit_params = glm_params.merge(passed_through_params.to_unsafe_h)
    {
      submit_path: users_sign_up_company_path(submit_params),
      first_name: current_user.first_name,
      last_name: current_user.last_name
    }
  end

  def should_ask_company_question?
    TRIAL_ONBOARDING_SOURCE_URLS.exclude?(glm_params[:glm_source])
  end

  def glm_params
    strong_memoize(:glm_params) do
      params.slice(:glm_source, :glm_content).to_unsafe_h
    end
  end

  def trial_namespace_selector_data(namespace_create_errors)
    namespace_selector_data(namespace_create_errors).merge(
      any_trial_eligible_namespaces: any_trial_eligible_namespaces?.to_s,
      items: namespace_options_for_listbox(trial_eligible_namespaces).to_json
    )
  end

  def duo_pro_trial_namespace_selector_data(namespace_create_errors)
    namespaces = duo_pro_trial_eligible_namespaces

    namespace_selector_data(namespace_create_errors).merge(
      any_trial_eligible_namespaces: namespaces.any?.to_s,
      items: namespace_options_for_listbox(namespaces).to_json
    )
  end

  def glm_source
    ::Gitlab.config.gitlab.host
  end

  def trial_selection_intro_text
    if any_trial_eligible_namespaces?
      s_('Trials|You can apply your trial to a new group or an existing group.')
    else
      s_('Trials|Create a new group to start your GitLab Ultimate trial.')
    end
  end

  def show_tier_badge_for_new_trial?(namespace, user)
    ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
      !namespace.paid? &&
      namespace.private? &&
      namespace.never_had_trial? &&
      can?(user, :read_billing, namespace)
  end

  def namespace_options_for_listbox(namespaces)
    group_options = namespaces.map { |n| { text: n.name, value: n.id.to_s } }
    options = [
      {
        text: _('New'),
        options: [
          {
            text: _('Create group'),
            value: '0'
          }
        ]
      }
    ]

    options.push(text: _('Groups'), options: group_options) unless group_options.empty?

    options
  end

  private

  def passed_through_params
    params.slice(
      :trial,
      :role,
      :registration_objective,
      :jobs_to_be_done_other,
      :opt_in
    )
  end

  def trial_eligible_namespaces
    current_user.manageable_namespaces_eligible_for_trial
  end

  def any_trial_eligible_namespaces?
    trial_eligible_namespaces.any?
  end

  def duo_pro_trial_eligible_namespaces
    Users::DuoProTrialEligibleNamespacesFinder.new(current_user).execute
  end

  def _lead_form_data
    {
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      company_name: current_user.organization
    }.merge(
      params.permit(
        :first_name, :last_name, :company_name, :company_size, :phone_number, :country, :state
      ).to_h.symbolize_keys
    )
  end

  def namespace_selector_data(namespace_create_errors)
    {
      new_group_name: params[:new_group_name],
      # This may allow through an unprivileged submission of trial since we don't validate access on the passed in
      # namespace_id.
      # That is ok since we validate this on submission.
      initial_value: params[:namespace_id],
      namespace_create_errors: namespace_create_errors
    }
  end
end
