# frozen_string_literal: true

module RemoteDevelopment
  module Settings
    class DefaultSettings
      include Messages

      UNDEFINED = nil

      # ALL REMOTE DEVELOPMENT SETTINGS MUST BE DECLARED HERE.
      # See ../README.md for more details.
      # @return [Hash]
      def self.default_settings
        {
          # NOTE: default_branch_name is not actually used by Remote Development, it is simply a placeholder to drive
          #       the logic for reading settings from ::Gitlab::CurrentSettings. It can be replaced when there is an
          #       actual Remote Development entry in ::Gitlab::CurrentSettings.
          default_branch_name: [UNDEFINED, String],
          default_max_hours_before_termination: [24, Integer],
          max_hours_before_termination_limit: [120, Integer],
          project_cloner_image: ['alpine/git:2.36.3', String],
          tools_injector_image: [
            "registry.gitlab.com/gitlab-org/gitlab-web-ide-vscode-fork/web-ide-injector:9", String
          ],
          vscode_extensions_gallery: [
            {
              service_url: "https://open-vsx.org/vscode/gallery",
              item_url: "https://open-vsx.org/vscode/item",
              resource_url_template: "https://open-vsx.org/api/{publisher}/{name}/{version}/file/{path}"
            },
            Hash
          ],
          vscode_extensions_gallery_metadata: [
            {}, # NOTE: There is no default, the value is always generated by ExtensionsGalleryMetadataGenerator
            Hash
          ],
          full_reconciliation_interval_seconds: [3600, Integer],
          partial_reconciliation_interval_seconds: [10, Integer]
        }
      end
    end
  end
end
