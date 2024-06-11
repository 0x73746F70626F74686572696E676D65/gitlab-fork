# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Output
        class ResponsePayloadBuilder
          include Messages
          include UpdateTypes

          ALL_RESOURCES_INCLUDED = :all_resources_included
          PARTIAL_RESOURCES_INCLUDED = :partial_resources_included
          NO_RESOURCES_INCLUDED = :no_resources_included

          # @param [Hash] context
          # @return [Hash]
          def self.build(context)
            context => {
              update_type: String => update_type,
              workspaces_to_be_returned: Array => workspaces_to_be_returned,
              settings: {
                full_reconciliation_interval_seconds: Integer => full_reconciliation_interval_seconds,
                partial_reconciliation_interval_seconds: Integer => partial_reconciliation_interval_seconds
              },
              logger: logger
            }

            observability_for_rails_infos = {}

            # Create an array of workspace_rails_info hashes based on the workspaces. These indicate the desired updates
            # to the workspace, which will be returned in the payload to the agent to be applied to kubernetes
            workspace_rails_infos = workspaces_to_be_returned.map do |workspace|
              config_to_apply, config_to_apply_resources_include_type = config_to_apply(workspace: workspace,
                update_type: update_type, logger: logger)
              observability_for_rails_infos[workspace.name] = {
                config_to_apply_resources_included: config_to_apply_resources_include_type
              }

              {
                name: workspace.name,
                namespace: workspace.namespace,
                desired_state: workspace.desired_state,
                actual_state: workspace.actual_state,
                deployment_resource_version: workspace.deployment_resource_version,
                # NOTE: config_to_apply should be returned as null if config_to_apply returned nil
                config_to_apply: config_to_apply
              }
            end

            settings = {
              full_reconciliation_interval_seconds: full_reconciliation_interval_seconds,
              partial_reconciliation_interval_seconds: partial_reconciliation_interval_seconds
            }

            context.merge(
              response_payload: {
                workspace_rails_infos: workspace_rails_infos,
                settings: settings
              },
              observability_for_rails_infos: observability_for_rails_infos
            )
          end

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [String (frozen)] update_type
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array]
          def self.config_to_apply(workspace:, update_type:, logger:)
            return nil, NO_RESOURCES_INCLUDED unless should_include_config_to_apply?(update_type: update_type,
              workspace: workspace)

            include_all_resources = update_type == FULL || workspace.force_include_all_resources
            resources_include_type = include_all_resources ? ALL_RESOURCES_INCLUDED : PARTIAL_RESOURCES_INCLUDED

            workspace_resources =
              case workspace.config_version
              when ConfigVersion::LATEST_VERSION
                DesiredConfigGenerator.generate_desired_config(
                  workspace: workspace,
                  include_all_resources: include_all_resources,
                  logger: logger
                )
              else
                namespace = "RemoteDevelopment::Workspaces::Reconcile::Output"
                generator_class_name = "#{namespace}::DesiredConfigGeneratorV#{workspace.config_version}"
                generator_class = Object.const_get(generator_class_name, false)
                generator_class.generate_desired_config(
                  workspace: workspace,
                  include_all_resources: include_all_resources,
                  logger: logger
                )
              end

            desired_config_to_apply_array = workspace_resources.map do |resource|
              YAML.dump(Gitlab::Utils.deep_sort_hash(resource).deep_stringify_keys)
            end

            return nil, NO_RESOURCES_INCLUDED unless desired_config_to_apply_array.present?

            [desired_config_to_apply_array.join, resources_include_type]
          end

          # @param [String (frozen)] update_type
          # @param [RemoteDevelopment::Workspace] workspace
          # @return [Boolean]
          def self.should_include_config_to_apply?(update_type:, workspace:)
            update_type == FULL ||
              workspace.force_include_all_resources ||
              workspace.desired_state_updated_more_recently_than_last_response_to_agent?
          end
          private_class_method :should_include_config_to_apply?, :config_to_apply
        end
      end
    end
  end
end
