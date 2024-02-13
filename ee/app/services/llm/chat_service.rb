# frozen_string_literal: true

module Llm
  class ChatService < BaseService
    private

    def ai_action
      :chat
    end

    def perform
      if options[:agent_version_id]
        agent_version = Ai::AgentVersion.find_by_id(options[:agent_version_id].model_id)
        return error(agent_not_found_message) if agent_version.nil?

        return error(insufficient_agent_permission_message) unless Ability.allowed?(user, :read_ai_agents,
          agent_version.project)

        @options = options.merge(agent_version_id: agent_version.id)
      end

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
