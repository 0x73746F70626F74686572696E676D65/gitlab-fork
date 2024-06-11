# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class ProjectClonerComponentInjector
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.inject(context)
          context => {
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            params: Hash => params,
            settings: Hash => settings
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => { path: String => volume_path }
          params => {
            project: Project => project,
            devfile_ref: String => devfile_ref,
          }
          settings => {
            project_cloner_image: String => image,
          }

          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/408448
          #       replace the alpine/git docker image with one that is published by gitlab for security / reliability
          #       reasons
          clone_dir = "#{volume_path}/#{project.path}"
          project_url = project.http_url_to_repo

          # The project is cloned only if one doesn't exist already.
          # This done to avoid resetting user's modifications to the workspace.
          # After cloning the project, set the user's git configuration - name and email.
          # The name and email are read from environment variable because we do not want to
          # store PII in the processed devfile in the database.
          # The environment variables are injected into the gl-cloner-injector container component
          # when the Kubernetes resources are generated.
          container_args = <<~SH.chomp
            if [ ! -d '#{clone_dir}' ];
            then
              git clone --branch #{Shellwords.shellescape(devfile_ref)} #{Shellwords.shellescape(project_url)} #{Shellwords.shellescape(clone_dir)};
            fi
          SH

          # TODO: https://gitlab.com/groups/gitlab-org/-/epics/10461
          #       implement better error handling to allow cloner to be able to deal with different categories of errors
          # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/408451
          cloner_component = {
            'name' => 'gl-cloner-injector',
            'container' => {
              'image' => image,
              'args' => [container_args],
              # command has been overridden here as the default command in the alpine/git
              # container invokes git directly
              'command' => %w[/bin/sh -c],
              'memoryLimit' => '256Mi',
              'memoryRequest' => '128Mi',
              'cpuLimit' => '500m',
              'cpuRequest' => '100m'
            }
          }

          processed_devfile['components'] ||= []
          processed_devfile['components'] << cloner_component

          # create a command that will invoke the cloner
          cloner_command = {
            'id' => 'gl-cloner-injector-command',
            'apply' => {
              'component' => cloner_component['name']
            }
          }
          processed_devfile['commands'] ||= []
          processed_devfile['commands'] << cloner_command

          # configure the workspace to run the cloner command upon workspace start
          processed_devfile['events'] ||= {}
          processed_devfile['events']['preStart'] ||= []
          processed_devfile['events']['preStart'] << cloner_command['id']

          context
        end
      end
    end
  end
end
