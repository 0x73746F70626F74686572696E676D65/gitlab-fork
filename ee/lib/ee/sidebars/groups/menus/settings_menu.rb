# frozen_string_literal: true

module EE
  module Sidebars
    module Groups
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override
          include ::GitlabSubscriptions::SubscriptionHelper
          include ::Groups::AnalyticsDashboardHelper

          override :configure_menu_items
          def configure_menu_items
            super

            if can?(context.current_user, :admin_group, context.group)
              insert_item_after(:general, roles_and_permissions_menu_item)
              insert_item_after(:integrations, webhooks_menu_item)
              insert_item_after(:ci_cd, analytics_menu_item)
              add_item(ldap_sync_menu_item)
              add_item(saml_sso_menu_item)
              add_item(saml_group_links_menu_item)
              add_item(domain_verification_menu_item)
              add_item(billing_menu_item)
              add_item(reporting_menu_item)
            else
              add_menu_item_for_abilities(general_menu_item, [:remove_group, :admin_compliance_framework,
                :manage_merge_request_settings])
              add_menu_item_for_abilities(integrations_menu_item, :admin_integrations)
              add_menu_item_for_abilities(access_tokens_menu_item, :read_resource_access_tokens)
              add_menu_item_for_abilities(repository_menu_item, [:admin_push_rules, :manage_deploy_tokens])
              add_menu_item_for_abilities(ci_cd_menu_item, [:admin_cicd_variables, :admin_runner])
              add_menu_item_for_abilities(billing_menu_item, :read_billing)
            end
          end

          private

          def add_menu_item_for_abilities(menu_item, abilities)
            add_item(menu_item) if can_any?(context.current_user, Array(abilities), context.group)
          end

          def roles_and_permissions_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :roles_and_permissions) unless custom_roles_enabled?

            ::Sidebars::MenuItem.new(
              title: _('Roles and Permissions'),
              link: group_settings_roles_and_permissions_path(context.group),
              active_routes: { controller: :roles_and_permissions },
              item_id: :roles_and_permissions
            )
          end

          def custom_roles_enabled?
            context.group.root? && context.group.licensed_feature_available?(:custom_roles) && gitlab_com_subscription?
          end

          def ldap_sync_menu_item
            unless ldap_sync_enabled?
              return ::Sidebars::NilMenuItem.new(item_id: :ldap_sync)
            end

            ::Sidebars::MenuItem.new(
              title: _('LDAP Synchronization'),
              link: group_ldap_group_links_path(context.group),
              active_routes: { path: 'ldap_group_links#index' },
              item_id: :ldap_sync
            )
          end

          def ldap_sync_enabled?
            ::Gitlab::Auth::Ldap::Config.group_sync_enabled? &&
              can?(context.current_user, :admin_ldap_group_links, context.group)
          end

          def saml_sso_menu_item
            unless saml_sso_enabled?
              return ::Sidebars::NilMenuItem.new(item_id: :saml_sso)
            end

            ::Sidebars::MenuItem.new(
              title: _('SAML SSO'),
              link: group_saml_providers_path(context.group),
              active_routes: { path: 'saml_providers#show' },
              item_id: :saml_sso
            )
          end

          def saml_sso_enabled?
            can?(context.current_user, :admin_group_saml, context.group)
          end

          def saml_group_links_menu_item
            unless can?(context.current_user, :admin_saml_group_links, context.group)
              return ::Sidebars::NilMenuItem.new(item_id: :saml_group_links)
            end

            ::Sidebars::MenuItem.new(
              title: s_('GroupSAML|SAML Group Links'),
              link: group_saml_group_links_path(context.group),
              active_routes: { path: 'saml_group_links#index' },
              item_id: :saml_group_links
            )
          end

          def domain_verification_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :domain_verification) unless domain_verification_available?

            ::Sidebars::MenuItem.new(
              title: _('Domain Verification'),
              link: group_settings_domain_verification_index_path(context.group),
              active_routes: { path: 'domain_verification#index' },
              item_id: :domain_verification
            )
          end

          def domain_verification_available?
            can?(context.current_user, :admin_group, context.group) && context.group.domain_verification_available?
          end

          def webhooks_menu_item
            unless webhooks_enabled?
              return ::Sidebars::NilMenuItem.new(item_id: :webhooks)
            end

            ::Sidebars::MenuItem.new(
              title: _('Webhooks'),
              link: group_hooks_path(context.group),
              active_routes: { path: 'hooks#index' },
              item_id: :webhooks
            )
          end

          def webhooks_enabled?
            context.group.licensed_feature_available?(:group_webhooks) ||
              context.show_promotions
          end

          def billing_menu_item
            unless billing_enabled?
              return ::Sidebars::NilMenuItem.new(item_id: :billing)
            end

            ::Sidebars::MenuItem.new(
              title: _('Billing'),
              link: group_billings_path(context.group),
              active_routes: { path: 'billings#index' },
              item_id: :billing
            )
          end

          def billing_enabled?
            ::Gitlab::CurrentSettings.should_check_namespace_plan?
          end

          def reporting_menu_item
            unless context.group.unique_project_download_limit_enabled?
              return ::Sidebars::NilMenuItem.new(item_id: :reporting)
            end

            ::Sidebars::MenuItem.new(
              title: s_('GroupSettings|Reporting'),
              link: group_settings_reporting_path(context.group),
              active_routes: { path: 'reporting#show' },
              item_id: :reporting
            )
          end

          def analytics_menu_item
            unless analytics_available?
              return ::Sidebars::NilMenuItem.new(item_id: :analytics)
            end

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: group_settings_analytics_path(context.group),
              active_routes: { path: %w[analytics#index] },
              item_id: :analytics
            )
          end

          def analytics_available?
            group_analytics_settings_available?(context.current_user, context.group)
          end
        end
      end
    end
  end
end
