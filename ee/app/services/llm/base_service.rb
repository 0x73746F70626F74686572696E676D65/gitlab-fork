# frozen_string_literal: true

module Llm
  class BaseService
    INVALID_MESSAGE = 'AI features are not enabled or resource is not permitted to be sent.'

    def initialize(user, resource, options = {})
      @user = user
      @resource = resource
      @options = options
      @logger = Gitlab::Llm::Logger.build
    end

    def execute
      unless valid?
        logger.debug(message: "Returning from Service due to validation")
        return error(INVALID_MESSAGE)
      end

      perform
    end

    def valid?
      return false if resource.respond_to?(:resource_parent) && !resource.resource_parent.member?(user)

      case resource
      when User
        ai_integration_enabled? && user == resource && user_can_send_to_ai?
      else
        ai_integration_enabled?
      end
    end

    private

    attr_reader :user, :resource, :options, :logger

    def perform
      raise NotImplementedError
    end

    def worker_perform(user, resource, action_name, options)
      request_id = SecureRandom.uuid
      options[:request_id] = request_id
      message = content(action_name)
      payload = { request_id: request_id, role: ::Gitlab::Llm::Cache::ROLE_USER, content: message }

      ::Gitlab::Llm::Cache.new(user).add(payload)
      return success(payload) if no_worker_message?(message)

      logger.debug(
        message: "Enqueuing CompletionWorker",
        user_id: user.id,
        resource_id: resource.id,
        resource_class: resource.class.name,
        request_id: request_id,
        action_name: action_name
      )

      if options[:sync] == true
        response_data = ::Llm::CompletionWorker.new.perform(
          user.id, resource.id, resource.class.name, action_name, options
        )
        payload.merge!(response_data)
      else
        ::Llm::CompletionWorker.perform_async(user.id, resource.id, resource.class.name, action_name, options)
      end

      success(payload)
    end

    def ai_integration_enabled?
      Feature.enabled?(:openai_experimentation)
    end

    # This check is used for features that do not act on a specific namespace, and the `resource` is a `User`.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/413520
    def user_can_send_to_ai?
      return true unless ::Gitlab.com?

      user.paid_namespaces(plans: ::EE::User::AI_SUPPORTED_PLANS).any? do |namespace|
        namespace.third_party_ai_features_enabled && namespace.experiment_features_enabled
      end
    end

    def success(data = {})
      ServiceResponse.success(payload: data)
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def content(action_name)
      action_name.to_s.humanize
    end

    def no_worker_message?(content)
      content == ::Gitlab::Llm::Cache::RESET_MESSAGE
    end
  end
end
