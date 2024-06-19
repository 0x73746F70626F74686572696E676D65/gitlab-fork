# frozen_string_literal: true

module Llm
  class BaseService
    INVALID_MESSAGE = 'AI features are not enabled or resource is not permitted to be sent.'
    MISSING_RESOURCE_ID_MESSAGE = 'ResourceId is required for slash command request.'

    def initialize(user, resource, options = {})
      @user = user
      @resource = resource
      @options = options
      @logger = Gitlab::Llm::Logger.build
    end

    def execute
      unless valid?
        logger.info(message: "Returning from Service due to validation")
        return error(INVALID_MESSAGE)
      end

      if Feature.enabled?(:require_resource_id, @group) && invalid_slash_command_request?
        logger.info(message: "Returning from Service due to missing resource id. Associated group: #{@group}")
        return error(MISSING_RESOURCE_ID_MESSAGE)
      end

      result = perform

      result.is_a?(ServiceResponse) ? result : success(ai_message: prompt_message)
    end

    def valid?
      return false if resource && !Gitlab::Llm::Utils::Authorizer.resource(resource: resource, user: user).allowed?

      ai_integration_enabled? && user_can_send_to_ai?
    end

    def invalid_slash_command_request?
      true if contains_ai_action? && prompt_message.slash_command_prompt? &&
        !prompt_message.resource.present?
    end

    private

    attr_reader :user, :resource, :options, :logger

    def perform
      raise NotImplementedError
    end

    def ai_integration_enabled?
      ::Feature.enabled?(:ai_global_switch, type: :ops)
    end

    def user_can_send_to_ai?
      return true unless ::Gitlab.com?

      user.any_group_with_ai_available?
    end

    def contains_ai_action?
      options.key?(:ai_action)
    end

    def prompt_message
      @prompt_message ||= build_prompt_message
    end

    def build_prompt_message(attributes = options)
      action_name = attributes[:ai_action] || ai_action
      message_attributes = {
        request_id: SecureRandom.uuid,
        content: content(action_name),
        role: ::Gitlab::Llm::AiMessage::ROLE_USER,
        ai_action: action_name,
        user: user,
        context: ::Gitlab::Llm::AiMessageContext.new(resource: resource, user_agent: attributes[:user_agent])
      }.merge(attributes)

      ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
    end

    def content(action_name)
      action_name.to_s.humanize
    end

    def schedule_completion_worker(job_options = options)
      message = prompt_message

      job_options[:start_time] = ::Gitlab::Metrics::System.monotonic_time

      logger.info_or_debug(
        message.user,
        message: "Enqueuing CompletionWorker",
        user_id: message.user.id,
        resource_id: message.resource&.id,
        resource_class: message.resource&.class&.name,
        request_id: message.request_id,
        action_name: message.ai_action,
        options: job_options
      )

      ::Llm::CompletionWorker.perform_for(message, job_options)
    end

    def success(payload)
      ServiceResponse.success(payload: payload)
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def namespace
      case resource
      when Group
        resource
      when Project
        resource.group
      when User
        nil
      else
        case resource&.resource_parent
        when Group
          resource.resource_parent
        when Project
          resource.resource_parent.group
        end
      end
    end

    def project
      if resource.is_a?(Project)
        resource
      elsif resource.is_a?(Group) || resource.is_a?(User)
        nil
      elsif resource&.resource_parent.is_a?(Project)
        resource.resource_parent
      end
    end
  end
end
