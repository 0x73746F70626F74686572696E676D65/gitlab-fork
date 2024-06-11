# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class ToolsComponentInjector
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.inject(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            settings: Hash => settings
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }
          settings => { tools_injector_image: String => image_from_settings }

          editor_port = WorkspaceCreator::WORKSPACE_PORT
          ssh_port = 60022
          tools_dir = "#{volume_path}/.gl-tools"
          enable_marketplace = allow_extensions_marketplace_in_workspace_feature_enabled?(context: context)

          # NOTE: We will always have exactly one tools_component found, because we have already
          #       validated this in post_flatten_devfile_validator.rb
          tools_component = processed_devfile['components'].find { |c| c.dig('attributes', 'gl/inject-editor') }

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409775 - choose image based on which editor is passed.
          inject_tools_components(
            processed_devfile: processed_devfile,
            tools_dir: tools_dir,
            image: image_from_settings
          )

          override_main_container(
            tools_component: tools_component,
            tools_dir: tools_dir,
            editor_port: editor_port,
            ssh_port: ssh_port,
            enable_marketplace: enable_marketplace
          )

          context
        end

        # @param [Hash] context
        # @return [Boolean]
        def self.allow_extensions_marketplace_in_workspace_feature_enabled?(context:)
          Feature.enabled?(
            :allow_extensions_marketplace_in_workspace,
            context.fetch(:params).fetch(:agent).project.root_namespace,
            type: :beta
          )
        end

        # @param [Hash] tools_component
        # @param [String] tools_dir
        # @param [Integer] editor_port
        # @param [Integer] ssh_port
        # @param [Boolean] enable_marketplace
        # @return [void]
        def self.override_main_container(tools_component:, tools_dir:, editor_port:, ssh_port:, enable_marketplace:)
          # This overrides the main container's command
          # Open issue to support both starting the editor and running the default command:
          # https://gitlab.com/gitlab-org/gitlab/-/issues/392853
          container_args = <<~"SH".chomp
            sshd_path=$(which sshd)
            if [ -x "$sshd_path" ]; then
              echo "Starting sshd on port ${GL_SSH_PORT}"
              $sshd_path -D -p $GL_SSH_PORT &
            else
              echo "'sshd' not found in path. Not starting SSH server."
            fi
            ${GL_TOOLS_DIR}/init_tools.sh
          SH
          tools_component['container']['command'] = %w[/bin/sh -c]
          tools_component['container']['args'] = [container_args]
          tools_component['container']['env'] = [] if tools_component['container']['env'].nil?
          tools_component['container']['env'] += [
            {
              'name' => 'GL_TOOLS_DIR',
              'value' => tools_dir
            },
            {
              'name' => 'GL_EDITOR_LOG_LEVEL',
              'value' => 'info'
            },
            {
              'name' => 'GL_EDITOR_PORT',
              'value' => editor_port.to_s
            },
            {
              'name' => 'GL_SSH_PORT',
              'value' => ssh_port.to_s
            },
            {
              'name' => 'GL_EDITOR_ENABLE_MARKETPLACE',
              'value' => enable_marketplace.to_s
            }
          ]

          tools_component['container']['endpoints'] = [] if tools_component['container']['endpoints'].nil?
          tools_component['container']['endpoints'].append(
            {
              'name' => 'editor-server',
              'targetPort' => editor_port,
              'exposure' => 'public',
              'secure' => true,
              'protocol' => 'https'
            },
            {
              'name' => 'ssh-server',
              'targetPort' => ssh_port,
              'exposure' => 'internal',
              'secure' => true
            }
          )
        end

        # @param [Hash] processed_devfile
        # @param [String] tools_dir
        # @param [String] image
        # @return [Array]
        def self.inject_tools_components(processed_devfile:, tools_dir:, image:)
          processed_devfile['components'] += tools_components(tools_dir: tools_dir, image: image)

          processed_devfile['commands'] = [] if processed_devfile['commands'].nil?
          processed_devfile['commands'] += [{
            'id' => 'gl-tools-injector-command',
            'apply' => {
              'component' => 'gl-tools-injector'
            }
          }]

          processed_devfile['events'] = {} if processed_devfile['events'].nil?
          processed_devfile['events']['preStart'] = [] if processed_devfile['events']['preStart'].nil?
          processed_devfile['events']['preStart'] += ['gl-tools-injector-command']
        end

        # @param [String] tools_dir
        # @param [String] image
        # @return [Array]
        def self.tools_components(tools_dir:, image:)
          [
            {
              'name' => 'gl-tools-injector',
              'container' => {
                'image' => image,
                'env' => [
                  {
                    'name' => 'GL_TOOLS_DIR',
                    'value' => tools_dir
                  }
                ],
                'memoryLimit' => '256Mi',
                'memoryRequest' => '128Mi',
                'cpuLimit' => '500m',
                'cpuRequest' => '100m'
              }
            }
          ]
        end
        private_class_method :allow_extensions_marketplace_in_workspace_feature_enabled?, :override_main_container,
          :inject_tools_components, :tools_components
      end
    end
  end
end
