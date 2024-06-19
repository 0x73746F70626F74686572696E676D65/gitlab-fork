# frozen_string_literal: true

module Llm
  module Internal
    class CompletionService < BaseService
      extend ::Gitlab::Utils::Override

      MAX_RUN_TIME = 30.seconds

      attr_reader :prompt_message, :options

      def initialize(prompt_message, options = {})
        @prompt_message = prompt_message
        @options = options
      end

      def execute
        return unless ai_action_enabled?(prompt_message)

        with_tracking(prompt_message.ai_action) do
          break unless resource_authorized?(prompt_message)

          log_perform(prompt_message)

          options.symbolize_keys!
          options[:extra_resource] = ::Llm::ExtraResourceFinder
            .new(prompt_message.user, options.delete(:referer_url)).execute

          completion = ::Gitlab::Llm::CompletionsFactory.completion!(prompt_message, options)
          logger.debug(message: "Got Completion Service from factory", class_name: completion.class.name)

          completion.execute
        end
      end

      private

      def with_tracking(ai_action)
        start_time = options[:start_time] || ::Gitlab::Metrics::System.monotonic_time

        response = yield

        update_error_rate(ai_action, response)
        update_duration_metric(ai_action, ::Gitlab::Metrics::System.monotonic_time - start_time)

        response
      rescue StandardError => err
        update_error_rate(ai_action)
        raise err
      end

      def log_perform(prompt_message)
        logger.debug(
          message: "Performing CompletionService",
          user_id: prompt_message.user.to_gid,
          resource_id: prompt_message.resource&.to_gid,
          action_name: prompt_message.ai_action,
          request_id: prompt_message.request_id,
          client_subscription_id: prompt_message.client_subscription_id
        )
      end

      def resource_authorized?(prompt_message)
        !prompt_message.resource ||
          prompt_message.user.can?("read_#{prompt_message.resource.to_ability_name}", prompt_message.resource)
      end

      def update_error_rate(ai_action_name, response = nil)
        completion = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST[ai_action_name.to_sym]
        return unless completion

        success = response.try(:errors)&.empty?

        Gitlab::Metrics::Sli::ErrorRate[:llm_completion].increment(
          labels: {
            feature_category: completion[:feature_category],
            service_class: completion[:service_class].name
          },
          error: !success
        )
      end

      def update_duration_metric(ai_action_name, duration)
        completion = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST[ai_action_name.to_sym]
        return unless completion

        labels = {
          feature_category: completion[:feature_category],
          service_class: completion[:service_class].name
        }
        Gitlab::Metrics::Sli::Apdex[:llm_completion].increment(
          labels: labels,
          success: duration <= MAX_RUN_TIME
        )
      end

      def ai_action_enabled?(prompt_message)
        if prompt_message.chat?
          Feature.enabled?(:ai_duo_chat_switch, type: :ops)
        else
          Feature.enabled?(:ai_global_switch, type: :ops)
        end
      end

      def logger
        @logger ||= Gitlab::Llm::Logger.build
      end
    end
  end
end
