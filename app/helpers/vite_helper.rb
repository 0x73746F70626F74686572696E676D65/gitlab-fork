# frozen_string_literal: true

module ViteHelper
  def vite_enabled?
    # vite is not production ready yet
    return false if Rails.env.production?

    Gitlab::Utils.to_boolean(ViteRuby.env['VITE_ENABLED'], default: false)
  end

  def vite_hmr_websocket_url
    ViteRuby.env['VITE_HMR_WS_URL']
  end

  def vite_hmr_http_url
    ViteRuby.env['VITE_HMR_HTTP_URL']
  end

  def vite_page_entrypoint_paths
    action = case controller.action_name
             when 'create' then 'new'
             when 'update' then 'edit'
             else controller.action_name
             end

    parts = (controller.controller_path.split('/') << action)

    parts.map
         .with_index { |part, idx| "pages.#{(parts[0, idx] << part).join('.')}.js" }
  end

  def universal_stylesheet_link_tag(path, **options)
    stylesheet_link_tag(path, **options)
  end

  def universal_path_to_stylesheet(path)
    ActionController::Base.helpers.stylesheet_path(path)
  end
end
