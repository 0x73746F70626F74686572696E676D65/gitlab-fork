# frozen_string_literal: true

module EE
  module IntegrationsHelper
    extend ::Gitlab::Utils::Override

    override :project_jira_issues_integration?
    def project_jira_issues_integration?
      @project.jira_issues_integration_available? && @project.jira_integration&.issues_enabled
    end

    override :integration_form_data
    def integration_form_data(integration, project: nil, group: nil)
      form_data = super

      if integration.is_a?(Integrations::Jira)
        form_data.merge!(
          show_jira_issues_integration: @project&.jira_issues_integration_available?.to_s,
          show_jira_vulnerabilities_integration: integration.jira_vulnerabilities_integration_available?.to_s,
          enable_jira_issues: integration.issues_enabled.to_s,
          enable_jira_vulnerabilities: integration.jira_vulnerabilities_integration_enabled?.to_s,
          project_key: integration.project_key,
          vulnerabilities_issuetype: integration.vulnerabilities_issuetype,
          upgrade_plan_path: @project && ::Gitlab::CurrentSettings.should_check_namespace_plan? ? upgrade_plan_path(@project.group) : nil
        )
      end

      form_data
    end

    def add_to_slack_link(project, slack_app_id)
      query = {
        scope: ::Projects::SlackApplicationInstallService::DEFAULT_SCOPES.join(','),
        client_id: slack_app_id,
        redirect_uri: slack_auth_project_settings_slack_url(project),
        state: form_authenticity_token
      }

      if ::Projects::SlackApplicationInstallService.use_v2_flow?
        authorize_url = ::Projects::SlackApplicationInstallService::SLACK_AUTHORIZE_URL
        query[:redirect_uri] += '?v2=true'
      else
        authorize_url = ::Projects::SlackApplicationInstallService::SLACK_AUTHORIZE_URL_LEGACY
      end

      "#{authorize_url}?#{query.to_query}"
    end

    def gitlab_slack_application_data(projects)
      {
        projects: (projects || []).to_json(only: [:id, :name], methods: [:avatar_url, :name_with_namespace]),
        sign_in_path: new_session_path(:user, redirect_to_referer: 'yes'),
        is_signed_in: current_user.present?.to_s,
        slack_link_path: slack_link_profile_slack_path,
        gitlab_logo_path: image_path('illustrations/gitlab_logo.svg'),
        slack_logo_path: image_path('illustrations/slack_logo.svg')
      }
    end

    def jira_issues_show_data
      {
        issues_show_path: project_integrations_jira_issue_path(@project, params[:id], format: :json),
        issues_list_path: project_integrations_jira_issues_path(@project)
      }
    end

    override :integration_event_title
    def integration_event_title(event)
      return _('Vulnerability') if event == 'vulnerability'

      super
    end

    override :default_integration_event_description
    def default_integration_event_description(event)
      return s_("ProjectService|Trigger event when a new, unique vulnerability is recorded. (Note: This feature requires an Ultimate plan.)") if event == 'vulnerability'

      super
    end
  end
end
