# frozen_string_literal: true

module Llm
  class CompletionWorker
    include ApplicationWorker

    idempotent!
    data_consistency :delayed
    feature_category :team_planning
    urgency :low

    def perform(user_id, resource_id, resource_class, ai_action_name, options = {})
      logger.debug(
        message: "Performing CompletionWorker",
        user_id: user_id,
        resource_id: resource_id,
        action_name: ai_action_name
      )

      return unless Feature.enabled?(:openai_experimentation)

      options.symbolize_keys!

      user = User.find_by_id(user_id)
      return unless user

      resource = find_resource(resource_id, resource_class)
      return unless resource
      return unless user.can?("read_#{resource.to_ability_name}", resource)
      return unless resource.send_to_ai?

      params = { request_id: options.delete(:request_id) }

      ai_completion = ::Gitlab::Llm::CompletionsFactory.completion(ai_action_name.to_sym, params)
      logger.debug(message: "Getting Completion Service from factory", class_name: ai_completion.class.name)

      ai_completion.execute(user, resource, options) if ai_completion
    end

    private

    def logger
      @logger ||= Gitlab::Llm::Logger.build
    end

    def find_resource(resource_id, resource_class)
      resource_class.classify.constantize.find_by_id(resource_id)
    end
  end
end
