# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        class SingleActionExecutor
          include Gitlab::Utils::StrongMemoize
          include Concerns::AiDependent
          include Langsmith::RunHelpers

          attr_reader :tools, :user_input, :context, :response_handler
          attr_accessor :iterations

          MAX_ITERATIONS = 10
          RESPONSE_TYPE_TOOL = 'tool'

          # @param [String] user_input - a question from a user
          # @param [Array<Tool>] tools - an array of Tools defined in the tools module.
          # @param [GitlabContext] context - Gitlab context containing useful context information
          # @param [ResponseService] response_handler - Handles returning the response to the client
          # @param [ResponseService] stream_response_handler - Handles streaming chunks to the client
          def initialize(user_input:, tools:, context:, response_handler:, stream_response_handler: nil)
            @user_input = user_input
            @tools = tools
            @context = context
            @iterations = 0
            @logger = Gitlab::Llm::Logger.build
            @response_handler = response_handler
            @stream_response_handler = stream_response_handler
          end

          def execute
            @agent_scratchpad = []
            MAX_ITERATIONS.times do
              step = {}
              thoughts = execute_streamed_request

              answer = Answer.from_response(
                response_body: thoughts,
                tools: tools,
                context: context,
                parser_klass: Parsers::SingleActionParser
              )

              return answer if answer.is_final?

              step[:thought] = answer.suggestions
              step[:tool] = answer.tool
              step[:tool_input] = user_input

              tool_class = answer.tool

              picked_tool_action(tool_class)

              tool = tool_class.new(
                context: context,
                options: {
                  input: user_input,
                  suggestions: answer.suggestions
                },
                stream_response_handler: stream_response_handler
              )

              tool_answer = tool.execute

              return tool_answer if tool_answer.is_final?

              step[:observation] = tool_answer.content.strip
              @agent_scratchpad.push(step)
            end

            Answer.default_final_answer(context: context)
          rescue Net::ReadTimeout => error
            Gitlab::ErrorTracking.track_exception(error)
            Answer.error_answer(
              context: context,
              content: _("I'm sorry, I couldn't respond in time. Please try again."),
              error_code: "A1000"
            )
          rescue Gitlab::Llm::AiGateway::Client::ConnectionError => error
            Gitlab::ErrorTracking.track_exception(error)
            Answer.error_answer(
              context: context,
              error_code: "A1001"
            )
          end
          traceable :execute, name: 'Run ReAct'

          private

          def streamed_content(_content, chunk)
            chunk[:content]
          end

          def execute_streamed_request
            request(&streamed_request_handler(Answers::StreamedJson.new))
          end

          attr_reader :logger, :stream_response_handler

          # This method should not be memoized because the input variables change over time
          def prompt
            { prompt: user_input, options: prompt_options }
          end

          def prompt_options
            @options = {
              agent_scratchpad: @agent_scratchpad,
              conversation: conversation,
              current_resource_type: current_resource_type,
              current_resource_content: current_resource_content,
              single_action_agent: true
            }
          end

          def picked_tool_action(tool_class)
            logger.info(message: "Picked tool", tool: tool_class.to_s)

            stream_response_handler.execute(
              response: Gitlab::Llm::Chain::ToolResponseModifier.new(tool_class),
              options: {
                role: ::Gitlab::Llm::ChatMessage::ROLE_SYSTEM,
                type: RESPONSE_TYPE_TOOL
              }
            )
          end

          def conversation
            Utils::ChatConversation.new(context.current_user)
              .truncated_conversation_list
              .join(", ")
          end

          # TODO: remove issue condition when next issue is implemented
          # https://gitlab.com/gitlab-org/gitlab/-/issues/468905
          def current_resource_type
            context.current_page_type
          rescue ArgumentError
            nil
          end

          def current_resource_content
            context.current_page_short_description
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
