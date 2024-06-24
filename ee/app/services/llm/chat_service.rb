# frozen_string_literal: true

module Llm
  class ChatService < BaseService
    include Gitlab::InternalEventsTracking

    MISSING_RESOURCE_ID_MESSAGE = 'ResourceId is required for slash command request.'

    private

    def ai_action
      :chat
    end

    def perform
      if Feature.enabled?(:require_resource_id, @group) && invalid_slash_command_request?
        logger.info(message: "Returning from Service due to missing resource id. Associated group: #{@group}")
        return error(MISSING_RESOURCE_ID_MESSAGE)
      end

      if options[:agent_version_id]
        agent_version = Ai::AgentVersion.find_by_id(options[:agent_version_id].model_id)
        return error(agent_not_found_message) if agent_version.nil?

        return error(insufficient_agent_permission_message) unless Ability.allowed?(user, :read_ai_agents,
          agent_version.project)

        @options = options.merge(agent_version_id: agent_version.id)
      end

      track_internal_event(
        'request_duo_chat_response',
        user: user,
        project: project,
        namespace: namespace,
        feature_enabled_by_namespace_ids: user.ai_chat_enabled_namespace_ids
      )
      Gitlab::Tracking::AiTracking.track_event('request_duo_chat_response', user: user)

      prompt_message.save!
      GraphqlTriggers.ai_completion_response(prompt_message)

      schedule_completion_worker unless prompt_message.conversation_reset? || prompt_message.clean_history?
    end

    def content(_action_name)
      options[:content]
    end

    def ai_integration_enabled?
      ::Feature.enabled?(:ai_duo_chat_switch, type: :ops)
    end

    def invalid_slash_command_request?
      true if prompt_message.slash_command_prompt? && !prompt_message.resource.present?
    end

    def user_can_send_to_ai?
      user.can?(:access_duo_chat)
    end

    def agent_not_found_message
      _('Agent not found for provided id.')
    end

    def insufficient_agent_permission_message
      _('User does not have permission to modify agent.')
    end
  end
end
