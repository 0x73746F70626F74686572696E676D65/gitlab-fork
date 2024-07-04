# frozen_string_literal: true

module Sidebars
  module Admin
    module Menus
      class AiPoweredFeaturesMenu < ::Sidebars::Admin::BaseMenu
        override :configure_menu_items
        def configure_menu_items
          add_item(code_suggestions_menu_item)
          add_item(self_hosted_models_menu_item)
          add_item(features_menu_item)

          true
        end

        override :title
        def title
          s_('Admin|AI-powered features')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :extra_container_html_options
        def extra_container_html_options
          { testid: 'admin-ai-powered-features-link' }
        end

        private

        def code_suggestions_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Admin|GitLab Duo'),
            link: admin_code_suggestions_path,
            active_routes: { controller: :code_suggestions },
            item_id: :duo_pro_code_suggestions,
            container_html_options: { title: 'GitLab Duo' }
          )
        end

        def self_hosted_models_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Admin|Custom models'),
            link: admin_ai_self_hosted_models_path,
            active_routes: { controller: 'admin/ai/self_hosted_models' },
            item_id: :duo_pro_self_hosted_models,
            container_html_options: { title: 'Custom models' }
          )
        end

        def features_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Admin|Features'),
            link: admin_ai_feature_settings_path,
            active_routes: { controller: 'admin/ai/feature_settings' },
            item_id: :duo_pro_features,
            container_html_options: { title: 'Features' }
          )
        end
      end
    end
  end
end
