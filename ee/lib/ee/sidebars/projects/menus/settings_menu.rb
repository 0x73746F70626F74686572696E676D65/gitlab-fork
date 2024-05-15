# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override

          PERMITTABLE_MENU_ITEMS = {
            general_menu_item: [
              :view_edit_page
            ],
            access_tokens_menu_item: [
              :manage_resource_access_tokens
            ],
            repository_menu_item: [
              :admin_push_rules,
              :manage_deploy_tokens
            ],
            merge_requests_menu_item: [
              :manage_merge_request_settings
            ],
            ci_cd_menu_item: [
              :admin_cicd_variables
            ]
          }.freeze

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

          alias_method :build, :send

          def custom_roles_menu_items
            PERMITTABLE_MENU_ITEMS.filter_map do |(menu_item, permissions)|
              build(menu_item) if allowed_any?(*permissions)
            end
          end

          def allowed?(ability)
            return false if context.current_user.blank?

            can?(context.current_user, ability, context.project)
          end

          def allowed_any?(*abilities)
            abilities.any? do |ability|
              allowed?(ability)
            end
          end
        end
      end
    end
  end
end
