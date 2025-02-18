# frozen_string_literal: true

module Groups::SecurityFeaturesHelper
  def group_level_compliance_dashboard_available?(group)
    group.licensed_feature_available?(:group_level_compliance_dashboard) &&
      can?(current_user, :read_group_compliance_dashboard, group)
  end

  def authorize_compliance_dashboard!
    render_404 unless group_level_compliance_dashboard_available?(group)
  end

  def group_level_credentials_inventory_available?(group)
    can?(current_user, :read_group_credentials_inventory, group) &&
      group.licensed_feature_available?(:credentials_inventory) &&
      group.enforced_group_managed_accounts?
  end

  def group_level_security_dashboard_data(group)
    {
      projects_endpoint: expose_url(api_v4_groups_projects_path(id: group.id)),
      group_full_path: group.full_path,
      no_vulnerabilities_svg_path: image_path('illustrations/empty-state/empty-search-md.svg'),
      empty_state_svg_path: image_path('illustrations/empty-state/empty-dashboard-md.svg'),
      security_dashboard_empty_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
      vulnerabilities_export_endpoint: expose_path(api_v4_security_groups_vulnerability_exports_path(id: group.id)),
      can_admin_vulnerability: can?(current_user, :admin_vulnerability, group).to_s,
      can_view_false_positive: group.licensed_feature_available?(:sast_fp_reduction).to_s,
      has_projects: Project.for_group_and_its_subgroups(group).any?.to_s,
      dismissal_descriptions: dismissal_descriptions.to_json
    }
  end

  def group_security_discover_data(group)
    content = 'discover-group-security'

    {
      group: {
        id: group.id,
        name: group.name
      },
      link: {
        main: new_trial_registration_path(glm_source: 'gitlab.com', glm_content: content),
        secondary: group_billings_path(group.root_ancestor, source: content)
      }
    }
  end
end
