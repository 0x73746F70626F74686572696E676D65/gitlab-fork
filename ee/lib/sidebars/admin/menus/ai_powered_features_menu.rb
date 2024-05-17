# frozen_string_literal: true

module Sidebars
  module Admin
    module Menus
      class AiPoweredFeaturesMenu < ::Sidebars::Admin::BaseMenu
        override :configure_menu_items
        def configure_menu_items
          add_item(code_suggestions_menu_item)
          add_item(self_hosted_models_menu_item)

          true
        end

        override :title
        def title
          s_('Admin|AI-Powered Features')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :extra_container_html_options
        def extra_container_html_options
          { testid: 'admin-duo-pro-menu-link' }
        end

        private

        def code_suggestions_menu_item
          ::Sidebars::MenuItem.new(
            title: 'GitLab Duo Pro',
            link: admin_code_suggestions_path,
            active_routes: { controller: :code_suggestions },
            item_id: :duo_pro_code_suggestions,
            container_html_options: { title: 'GitLab Duo Pro' }
          )
        end

        def self_hosted_models_menu_item
          return unless Feature.enabled?(:ai_custom_model)  # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

          ::Sidebars::MenuItem.new(
            title: _('Models'),
            link: admin_ai_self_hosted_models_path,
            active_routes: { controller: 'admin/ai/self_hosted_models' },
            item_id: :duo_pro_self_hosted_models,
            container_html_options: { title: 'Models' }
          )
        end
      end
    end
  end
end
