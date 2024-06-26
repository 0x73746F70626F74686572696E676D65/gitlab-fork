# frozen_string_literal: true

module Gitlab
  module Llm
    module Completions
      class Chat < Base
        include Langsmith::RunHelpers
        include ::Gitlab::Utils::StrongMemoize

        attr_reader :context

        TOOLS = [
          ::Gitlab::Llm::Chain::Tools::IssueReader,
          ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
          ::Gitlab::Llm::Chain::Tools::EpicReader,
          ::Gitlab::Llm::Chain::Tools::CiEditorAssistant
        ].freeze

        COMMAND_TOOLS = TOOLS + [
          ::Gitlab::Llm::Chain::Tools::ExplainCode,
          ::Gitlab::Llm::Chain::Tools::WriteTests,
          ::Gitlab::Llm::Chain::Tools::RefactorCode,
          ::Gitlab::Llm::Chain::Tools::ExplainVulnerability
        ].freeze

        def initialize(prompt_message, ai_prompt_class, options = {})
          super

          # we should be able to switch between different providers that we know agent supports, by initializing the
          # one we like. At the moment Anthropic is default and some features may not be supported
          # by other providers.
          @context = ::Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: resource.try(:resource_parent)&.root_ancestor,
            resource: resource,
            ai_request: ai_request,
            extra_resource: options.delete(:extra_resource) || {},
            request_id: prompt_message.request_id,
            current_file: options.delete(:current_file),
            agent_version: options[:agent_version_id] && ::Ai::AgentVersion.find_by_id(options[:agent_version_id])
          )
        end

        def ai_request
          ::Gitlab::Llm::Chain::Requests::AiGateway.new(user, tracking_context: tracking_context)
        end

        def execute
          # This can be removed once all clients use the subscription with the `ai_action: "chat"` parameter.
          # We then can only use `chat_response_handler`.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/423080
          response_handler = ::Gitlab::Llm::ResponseService
            .new(context, response_options.except(:client_subscription_id))

          response = agent_or_tool_response(response_handler)
          response_modifier = Gitlab::Llm::Chain::ResponseModifier.new(response)

          context.tools_used.each do |tool|
            Gitlab::Tracking.event(
              self.class.to_s,
              'process_gitlab_duo_question',
              label: tool::NAME,
              property: prompt_message.request_id,
              namespace: context.container,
              user: user,
              value: response.status == :ok ? 1 : 0
            )
          end

          # Send full message to custom clientSubscriptionId at the end of streaming.
          if response_options[:client_subscription_id]
            ::Gitlab::Llm::ResponseService.new(context, response_options)
              .execute(response: response_modifier, save_message: false)
          end

          response_handler.execute(response: response_modifier)
          # response_post_processing # Temp fix for production issue
          response_modifier
        end
        traceable :execute, name: 'Run Duo Chat'

        private

        # allows conditional logic e.g. feature flagging
        def tools
          TOOLS
        end

        def response_post_processing
          return if Rails.env.development?
          return unless Gitlab::Saas.feature_available?(:duo_chat_categorize_question)

          service_options = {
            request_id: tracking_context[:request_id],
            message_id: prompt_message.id,
            question: prompt_message.content
          }
          ::Llm::ExecuteMethodService.new(user, user, :categorize_question, service_options).execute
        end

        def agent_or_tool_response(response_handler)
          if response_options[:client_subscription_id]
            stream_response_handler = ::Gitlab::Llm::ResponseService.new(context, response_options)
          end

          return execute_with_slash_command_tool(stream_response_handler) if slash_command

          execute_with_tool_chosen_by_ai(response_handler, stream_response_handler)
        end

        def execute_with_tool_chosen_by_ai(response_handler, stream_response_handler)
          Gitlab::Llm::Chain::Agents::ZeroShot::Executor.new(
            user_input: prompt_message.content,
            tools: tools,
            context: context,
            response_handler: response_handler,
            stream_response_handler: stream_response_handler
          ).execute
        end

        def execute_with_slash_command_tool(stream_response_handler)
          Gitlab::Tracking.event(
            self.class.to_s,
            'process_gitlab_duo_slash_command',
            label: slash_command.name,
            property: prompt_message.request_id,
            namespace: context.container,
            user: user,
            value: slash_command.user_input.present? ? 1 : 0
          )

          slash_command.tool::Executor.new(
            context: context,
            options: { input: options[:content] },
            stream_response_handler: stream_response_handler,
            command: slash_command
          ).execute
        end

        def slash_command
          return unless prompt_message.slash_command?

          Gitlab::Llm::Chain::SlashCommand.for(message: prompt_message, tools: COMMAND_TOOLS)
        end
        strong_memoize_attr :slash_command
      end
    end
  end
end
