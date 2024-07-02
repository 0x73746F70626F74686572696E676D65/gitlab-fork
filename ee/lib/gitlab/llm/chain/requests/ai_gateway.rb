# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Requests
        class AiGateway < Base
          extend ::Gitlab::Utils::Override

          include ::Gitlab::Llm::Concerns::AvailableModels
          include ::Gitlab::Llm::Concerns::AllowedParams
          include ::Gitlab::Llm::Concerns::EventTracking

          attr_reader :ai_client, :tracking_context

          ENDPOINT = '/v1/chat/agent'
          BASE_ENDPOINT = '/v1/chat'
          CHAT_V2_ENDPOINT = '/v2/chat/agent'
          DEFAULT_TYPE = 'prompt'
          DEFAULT_SOURCE = 'GitLab EE'
          TEMPERATURE = 0.1
          STOP_WORDS = ["\n\nHuman", "Observation:"].freeze
          DEFAULT_MAX_TOKENS = 2048

          def initialize(user, service_name: :duo_chat, tracking_context: {})
            @user = user
            @tracking_context = tracking_context
            @ai_client = ::Gitlab::Llm::AiGateway::Client.new(user, service_name: processed_service_name(service_name),
              tracking_context: tracking_context)
            @logger = Gitlab::Llm::Logger.build
          end

          def request(prompt, unit_primitive: nil)
            options = default_options.merge(prompt.fetch(:options, {}))
            return unless model_provider_valid?(options)

            v2_chat_schema = Feature.enabled?(:v2_chat_agent_integration, user) && options.delete(:single_action_agent)

            body = if v2_chat_schema
                     request_body_chat_2(prompt: prompt[:prompt], options: options)
                   else
                     request_body(prompt: prompt[:prompt], options: options)
                   end

            response = ai_client.stream(
              endpoint: endpoint(unit_primitive, v2_chat_schema),
              body: body
            ) do |data|
              yield data if block_given?
            end

            track_prompt_size(token_size(prompt[:prompt]), provider(options))
            track_response_size(token_size(response), provider(options))

            response
          end

          private

          attr_reader :user, :logger

          def default_options
            {
              temperature: TEMPERATURE,
              stop_sequences: STOP_WORDS,
              max_tokens_to_sample: DEFAULT_MAX_TOKENS
            }
          end

          def model(options)
            return options[:model] if options[:model].present?

            Feature.enabled?(:use_sonnet_35, user) ? CLAUDE_3_5_SONNET : CLAUDE_3_SONNET
          end

          def provider(options)
            AVAILABLE_MODELS.find do |_, models|
              models.include?(model(options))
            end&.first
          end

          def model_provider_valid?(options)
            provider(options)
          end

          def endpoint(unit_primitive, v2_chat_schema)
            if unit_primitive.present?
              "#{BASE_ENDPOINT}/#{unit_primitive}"
            elsif v2_chat_schema
              CHAT_V2_ENDPOINT
            else
              ENDPOINT
            end
          end

          def request_body(prompt:, options: {})
            {
              prompt_components: [{
                type: DEFAULT_TYPE,
                metadata: {
                  source: DEFAULT_SOURCE,
                  version: Gitlab.version_info.to_s
                },
                payload: {
                  content: prompt
                }.merge(payload_params(options)).merge(model_params(options))
              }],
              stream: true
            }
          end

          def model_params(options)
            if chat_feature_setting&.self_hosted?
              self_hosted_model = chat_feature_setting.self_hosted_model

              {
                provider: :litellm,
                model: self_hosted_model.model,
                model_endpoint: self_hosted_model.endpoint,
                model_api_key: self_hosted_model.api_token
              }
            else
              {
                provider: provider(options),
                model: model(options)
              }
            end
          end

          def request_body_chat_2(prompt:, options: {})
            option_params = {
              chat_history: "",
              agent_scratchpad: {
                agent_type: "react",
                steps: options[:agent_scratchpad]
              }
            }

            if options[:current_resource_type]
              option_params[:context] = {
                type: options[:current_resource_type],
                content: options[:current_resource_content]
              }
            end

            {
              prompt: prompt,
              options: option_params
            }
          end

          def payload_params(options)
            allowed_params = ALLOWED_PARAMS.fetch(provider(options))
            params = options.slice(*allowed_params)

            { params: params }.compact_blank
          end

          def token_size(content)
            # Anthropic's APIs don't send used tokens as part of the response, so
            # instead we estimate the number of tokens based on typical token size
            # one token is roughly 4 chars.
            content.to_s.size / 4
          end

          override :tracking_class_name
          def tracking_class_name(provider)
            TRACKING_CLASS_NAMES.fetch(provider)
          end

          def chat_feature_setting
            ::Ai::FeatureSetting.find_by_feature(:duo_chat)
          end

          def processed_service_name(service_name)
            return service_name unless service_name == :duo_chat
            return service_name unless chat_feature_setting&.self_hosted?

            :self_hosted_models
          end
        end
      end
    end
  end
end
