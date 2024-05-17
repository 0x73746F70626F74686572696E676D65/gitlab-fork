# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Panel
        include ::GitlabSubscriptions::CodeSuggestionsHelper
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::PushRulesMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::GeoMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::LabelsMenu,
            ::Sidebars::Admin::Menus::CredentialsMenu.new(context)
          )

          insert_menu_after(
            ::Sidebars::Admin::Menus::AbuseReportsMenu,
            ::Sidebars::Admin::Menus::SubscriptionMenu.new(context)
          )

          insert_code_suggestions_menu
        end

        private

        def insert_code_suggestions_menu
          return unless !gitlab_com_subscription? && gitlab_duo_available? && License.current&.paid?

          if ::Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
            insert_menu_after(
              ::Sidebars::Admin::Menus::SubscriptionMenu,
              ::Sidebars::Admin::Menus::AiPoweredFeaturesMenu.new(context)
            )
          else
            insert_menu_after(
              ::Sidebars::Admin::Menus::SubscriptionMenu,
              ::Sidebars::Admin::Menus::CodeSuggestionsMenu.new(context)
            )
          end
        end
      end
    end
  end
end
