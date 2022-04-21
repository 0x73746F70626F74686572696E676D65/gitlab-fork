# frozen_string_literal: true

module EE::SecurityOrchestrationHelper
  def can_update_security_orchestration_policy_project?(container)
    can?(current_user, :update_security_orchestration_policy_project, container)
  end

  def assigned_policy_project(container)
    return unless container&.security_orchestration_policy_configuration

    orchestration_policy_configuration = container.security_orchestration_policy_configuration
    security_policy_management_project = orchestration_policy_configuration.security_policy_management_project

    {
      id: security_policy_management_project.to_global_id.to_s,
      name: security_policy_management_project.name,
      full_path: security_policy_management_project.full_path,
      branch: security_policy_management_project.default_branch_or_main
    }
  end

  def orchestration_policy_data(container, policy_type = nil, policy = nil, environment = nil, approvers = nil)
    return unless container

    disable_scan_policy_update = !can_update_security_orchestration_policy_project?(container)

    policy_data = {
      assigned_policy_project: assigned_policy_project(container).to_json,
      disable_scan_policy_update: disable_scan_policy_update.to_s,
      policy: policy&.to_json,
      policy_editor_empty_state_svg_path: image_path('illustrations/monitoring/unable_to_connect.svg'),
      policy_type: policy_type,
      policies_path: security_policies_path(container),
      scan_policy_documentation_path: help_page_path('user/application_security/policies/index')
    }

    if container.is_a?(::Project)
      policy_data.merge(
        project_path: container.full_path,
        project_id: container.id,
        default_environment_id: container.default_environment&.id || -1,
        network_policies_endpoint: project_security_network_policies_path(container),
        create_agent_help_path: help_page_url('user/clusters/agent/install/index'),
        network_documentation_path: help_page_path('user/application_security/policies/index'),
        environments_endpoint: project_environments_path(container),
        environment_id: environment&.id,
        scan_result_approvers: approvers&.to_json
      )
    else
      policy_data.merge(
        namespace_path: container.full_path,
        namespace_id: container.id
      )
    end
  end

  def security_policies_path(container)
    container.is_a?(::Project) ? project_security_policies_path(container) : group_security_policies_path(container)
  end
end
