# frozen_string_literal: true

module RemoteDevelopment
  module AgentConfig
    class Updater
      include Messages
      UNLIMITED_QUOTA = -1
      NETWORK_POLICY_EGRESS_DEFAULT = [
        {
          allow: "0.0.0.0/0",
          except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
        }
      ].freeze
      DEFAULT_RESOURCES_PER_WORKSPACE_CONTAINER_DEFAULT = {}.freeze
      MAX_RESOURCES_PER_WORKSPACE_DEFAULT = {}.freeze

      # @param [Hash] value
      # @return [Result]
      def self.update(value)
        value => { agent: Clusters::Agent => agent, config: Hash => config }
        config_from_agent_config_file = config[:remote_development]

        unless config_from_agent_config_file
          return Result.ok(
            AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new({ skipped_reason: :no_config_file_entry_found })
          )
        end

        remote_development_agent_config = find_or_initialize_remote_development_agent_config(
          agent: agent,
          config_from_agent_config_file: config_from_agent_config_file
        )

        model_errors = nil
        workspaces_update_all_error = nil

        ApplicationRecord.transaction do
          # First, create or update the remote_development_agent_config record

          unless remote_development_agent_config.save
            model_errors = remote_development_agent_config.errors
            raise ActiveRecord::Rollback
          end

          # Then, update the associated workspaces even if there were no material changes to the agent config

          workspaces_update_fields = { force_include_all_resources: true }

          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          if remote_development_agent_config.dns_zone_previously_was
            workspaces_update_fields[:dns_zone] = remote_development_agent_config.dns_zone
          end

          begin
            remote_development_agent_config.workspaces.desired_state_not_terminated.touch_all
            remote_development_agent_config.workspaces.desired_state_not_terminated.update_all(workspaces_update_fields)
          rescue ActiveRecord::ActiveRecordError => e
            workspaces_update_all_error = "Error updating associated workspaces with update_all: #{e.message}"
            raise ActiveRecord::Rollback
          end
        end

        return Result.err(AgentConfigUpdateFailed.new({ errors: model_errors })) if model_errors.present?

        if workspaces_update_all_error
          return Result.err(AgentConfigUpdateFailed.new({ details: workspaces_update_all_error }))
        end

        Result.ok(AgentConfigUpdateSuccessful.new({ remote_development_agent_config: remote_development_agent_config }))
      end

      # @param [Clusters::Agent] agent
      # @param [Hash] config_from_agent_config_file
      # @return [RemoteDevelopement::RemoteDevelopmentAgentConfig]
      def self.find_or_initialize_remote_development_agent_config(agent:, config_from_agent_config_file:)
        model_instance = RemoteDevelopmentAgentConfig.find_or_initialize_by(agent: agent) # rubocop:todo CodeReuse/ActiveRecord -- Use a finder class here

        model_instance.enabled = config_from_agent_config_file.fetch(:enabled, false)
        model_instance.workspaces_quota = config_from_agent_config_file.fetch(:workspaces_quota, UNLIMITED_QUOTA)
        model_instance.workspaces_per_user_quota = config_from_agent_config_file.fetch(:workspaces_per_user_quota,
          UNLIMITED_QUOTA)
        model_instance.dns_zone = config_from_agent_config_file[:dns_zone]
        model_instance.network_policy_enabled =
          config_from_agent_config_file.fetch(:network_policy, {}).fetch(:enabled, true)
        model_instance.network_policy_egress =
          config_from_agent_config_file.fetch(:network_policy, {}).fetch(:egress, NETWORK_POLICY_EGRESS_DEFAULT)
        model_instance.gitlab_workspaces_proxy_namespace =
          config_from_agent_config_file.fetch(:gitlab_workspaces_proxy, {}).fetch(:namespace, 'gitlab-workspaces')
        model_instance.default_resources_per_workspace_container =
          config_from_agent_config_file.fetch(:default_resources_per_workspace_container, {})
        model_instance.max_resources_per_workspace =
          config_from_agent_config_file.fetch(:max_resources_per_workspace, {})

        model_instance
      end
      private_class_method :find_or_initialize_remote_development_agent_config
    end
  end
end
