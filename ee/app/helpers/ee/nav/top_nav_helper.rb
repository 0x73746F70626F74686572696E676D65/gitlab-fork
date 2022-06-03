# frozen_string_literal: true

module EE
  module Nav
    module TopNavHelper
      extend ::Gitlab::Utils::Override

      private

      override :build_view_model
      def build_view_model(builder:, project:, group:)
        super

        if dashboard_nav_link?(:environments)
          builder.add_primary_menu_item(
            id: 'environments',
            title: _('Environments'),
            icon: 'environment',
            data: { qa_selector: 'environment_link', **menu_data_tracking_attrs('environments') },
            href: operations_environments_path
          )
        end

        if dashboard_nav_link?(:operations)
          builder.add_primary_menu_item(
            id: 'operations',
            title: _('Operations'),
            icon: 'cloud-gear',
            data: { qa_selector: 'operations_link', **menu_data_tracking_attrs('operations') },
            href: operations_path
          )
        end

        if dashboard_nav_link?(:security)
          builder.add_primary_menu_item(
            id: 'security',
            title: _('Security'),
            icon: 'shield',
            data: { qa_selector: 'security_link', **menu_data_tracking_attrs('security') },
            href: security_dashboard_path
          )
        end

        if ::Gitlab::Geo.secondary? && ::Gitlab::Geo.primary_node_configured?
          title = _('Go to primary site')

          builder.add_secondary_menu_item(
            id: 'geo',
            title: title,
            icon: 'location-dot',
            data: { qa_selector: 'menu_item_link', qa_title: title, **menu_data_tracking_attrs(title) },
            href: ::Gitlab::Geo.primary_node.url
          )
        end
      end

      override :projects_submenu_items
      def projects_submenu_items(builder:)
        super

        if current_user.can?(:list_removable_projects)
          title = _('Pending deletion')

          builder.add_primary_menu_item(
            id: 'deleted',
            title: title,
            data: { qa_selector: 'menu_item_link', qa_title: title, **menu_data_tracking_attrs(title) },
            href: removed_dashboard_projects_path
          )
        end
      end
    end
  end
end
