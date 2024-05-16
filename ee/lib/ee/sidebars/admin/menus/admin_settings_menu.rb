# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module AdminSettingsMenu
          include ::GitlabSubscriptions::SubscriptionHelper
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_after(:general_settings, roles_and_permissions_menu_item)
            insert_item_after(:roles_and_permissions, advanced_search_menu_item)
            insert_item_after(:admin_reporting, templates_menu_item)
            insert_item_after(:admin_ci_cd, security_and_compliance_menu_item)
            insert_item_after(:security_and_compliance_menu_item, analytics_menu_item)

            true
          end

          private

          def roles_and_permissions_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :roles_and_permissions) unless custom_roles_enabled?

            ::Sidebars::MenuItem.new(
              title: _('Roles and Permissions'),
              link: admin_application_settings_roles_and_permissions_path,
              active_routes: { controller: :roles_and_permissions },
              item_id: :roles_and_permissions
            )
          end

          def custom_roles_enabled?
            ::License.feature_available?(:custom_roles) && !gitlab_com_subscription?
          end

          def advanced_search_menu_item
            unless ::License.feature_available?(:elastic_search)
              return ::Sidebars::NilMenuItem.new(item_id: :advanced_search)
            end

            ::Sidebars::MenuItem.new(
              title: _('Search'),
              link: advanced_search_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#advanced_search' },
              item_id: :advanced_search,
              container_html_options: { testid: 'admin-settings-advanced-search-link' }
            )
          end

          def templates_menu_item
            unless ::License.feature_available?(:custom_file_templates)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_templates)
            end

            ::Sidebars::MenuItem.new(
              title: _('Templates'),
              link: templates_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#templates' },
              item_id: :admin_templates,
              container_html_options: { testid: 'admin-settings-templates-link' }
            )
          end

          def security_and_compliance_menu_item
            unless ::License.feature_available?(:license_scanning)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_security_and_compliance)
            end

            ::Sidebars::MenuItem.new(
              title: _('Security and Compliance'),
              link: security_and_compliance_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#security_and_compliance' },
              item_id: :admin_security_and_compliance,
              container_html_options: { testid: 'admin-security-and-compliance-link' }
            )
          end

          def analytics_menu_item
            unless ::License.feature_available?(:product_analytics) &&
                ::Feature.enabled?(:product_analytics_admin_settings)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_analytics)
            end

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: analytics_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#analytics' },
              item_id: :admin_analytics,
              container_html_options: { testid: 'admin-analytics-link' }
            )
          end
        end
      end
    end
  end
end
