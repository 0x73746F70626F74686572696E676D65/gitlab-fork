# frozen_string_literal: true

module Llm
  class CompletionWorker
    include ApplicationWorker

    idempotent!
    feature_category :ai_abstraction_layer
    urgency :low
    data_consistency :sticky
    worker_has_external_dependencies!
    deduplicate :until_executed

    class << self
      def serialize_message(message)
        message.to_h.tap do |hash|
          hash['user'] &&= hash['user'].to_gid
          hash['context'] = hash['context'].to_h
          hash['context']['resource'] &&= hash['context']['resource'].to_gid
        end
      end

      def deserialize_message(message_hash, options)
        message_hash['user'] &&= GitlabSchema.parse_gid(message_hash['user']).find
        message_hash['context'] = begin
          message_hash['context']['resource'] &&= GitlabSchema.parse_gid(message_hash['context']['resource']).find
          ::Gitlab::Llm::AiMessageContext.new(message_hash['context'])
        end

        ::Gitlab::Llm::AiMessage.for(action: message_hash['ai_action']).new(options.merge(message_hash))
      end

      def perform_for(message, options = {})
        # set SESSION_ID_HASH_KEY to ensure inside Sidekiq `Gitlab::Session.current` is not nil
        with_ip_address_state.set(
          Gitlab::SidekiqMiddleware::SetSession::Server::SESSION_ID_HASH_KEY => ::Gitlab::Session.session_id_for_worker
        ).perform_async(serialize_message(message), options)
      end
    end

    def perform(prompt_message_hash, options = {})
      ai_prompt_message = self.class.deserialize_message(prompt_message_hash, options)

      # set warden to ensure SsoEnforcer#in_context_of_user_web_activity? returns true
      session = Gitlab::Session.current
      if Feature.enabled?(:duo_chat_set_warden, ai_prompt_message.user) &&
          session && !session.key?('warden.user.user.key')

        session['warden.user.user.key'] = User.serialize_into_session(ai_prompt_message.user)
      end

      Gitlab::Llm::Tracking.event_for_ai_message(
        self.class.to_s, "perform_completion_worker", ai_message: ai_prompt_message
      )

      Internal::CompletionService.new(ai_prompt_message, options).execute
    end
  end
end
