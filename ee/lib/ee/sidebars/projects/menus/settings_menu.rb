# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_after(:monitor, analytics_menu_item)

            true
          end

          def analytics_menu_item
            unless ::Feature.enabled?(:combined_analytics_dashboards, context.project) && !context.project.personal?
              return ::Sidebars::NilMenuItem.new(item_id: :analytics)
            end

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: project_settings_analytics_path(context.project),
              active_routes: { path: %w[analytics#index] },
              item_id: :analytics
            )
          end

          private

          override :enabled_menu_items
          def enabled_menu_items
            return super if can?(context.current_user, :admin_project, context.project)

            custom_roles_menu_items
          end

          def custom_roles_menu_items
            items = []
            return items unless context.current_user

            items << general_menu_item if custom_roles_general_menu_item?
            items << access_tokens_menu_item if custom_roles_access_token_menu_item?
            items << repository_menu_item if custom_roles_repository_menu_item?
            items << merge_requests_menu_item if custom_roles_merge_requests_menu_item?
            items << ci_cd_menu_item if custom_roles_ci_cd_menu_item?

            items
          end

          def custom_roles_general_menu_item?
            can?(context.current_user, :view_edit_page, context.project)
          end

          def custom_roles_access_token_menu_item?
            can?(context.current_user, :manage_resource_access_tokens, context.project)
          end

          def custom_roles_repository_menu_item?
            can?(context.current_user, :admin_push_rules, context.project) ||
              can?(context.current_user, :manage_deploy_tokens, context.project)
          end

          def custom_roles_merge_requests_menu_item?
            can?(context.current_user, :manage_merge_request_settings, context.project)
          end

          def custom_roles_ci_cd_menu_item?
            can?(context.current_user, :admin_cicd_variables, context.project)
          end
        end
      end
    end
  end
end
