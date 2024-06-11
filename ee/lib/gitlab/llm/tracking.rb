# frozen_string_literal: true

module Gitlab
  module Llm
    class Tracking
      def self.event_for_ai_message(category, action, ai_message:)
        ::Gitlab::Tracking.event(
          category,
          action,
          label: ai_message.ai_action.to_s,
          property: ai_message.request_id,
          user: ai_message.user,
          client: client_for_user_agent(ai_message.context.user_agent)
        )
      end

      def self.client_for_user_agent(user_agent)
        return unless user_agent.present?

        user_agent.match?(Gitlab::Regex.vs_code_user_agent_regex) ? 'vscode' : 'web'
      end
      private_class_method :client_for_user_agent
    end
  end
end
