# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          class Executor
            include Gitlab::Utils::StrongMemoize
            include Concerns::AiDependent

            attr_reader :tools, :user_input, :context
            attr_accessor :iterations

            AGENT_NAME = 'GitLab Chat'
            MAX_ITERATIONS = 10

            PROVIDER_PROMPT_CLASSES = {
              anthropic: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::VertexAi
            }.freeze

            # @param [String] user_input - a question from a user
            # @param [Array<Tool>] tools - an array of Tools defined in the tools module.
            # @param [GitlabContext] context - Gitlab context containing useful context information
            def initialize(user_input:, tools:, context:)
              @user_input = user_input
              @tools = tools
              @context = context
              @iterations = 0
              @logger = Gitlab::Llm::Logger.build
            end

            def execute
              MAX_ITERATIONS.times do
                answer = Answer.from_response(response_body: request, tools: tools, context: context)

                return answer if answer.is_final?

                options[:agent_scratchpad] << "\nThought: #{answer.suggestions}"
                options[:agent_scratchpad] << answer.content.to_s

                tool_class = answer.tool
                logger.debug(message: "Picked tool", tool: tool_class.to_s)

                tool = tool_class.new(
                  context: context,
                  options: {
                    input: user_input,
                    suggestions: options[:agent_scratchpad]
                  }
                )

                tool_answer = tool.execute

                return tool_answer if tool_answer.is_final?

                options[:agent_scratchpad] << "Observation: #{tool_answer.content}\n"
              end

              Answer.final_answer(context: context, content: Answer.default_final_answer)
            end

            private

            attr_reader :logger

            # This method should not be memoized because the input variables change over time
            def base_prompt
              Utils::Prompt.no_role_text(PROMPT_TEMPLATE, options)
            end

            def options
              @options ||= {
                tool_names: tools.map { |tool_class| tool_class::Executor::NAME }.join(', '),
                tools_definitions: tools.map do |tool_class|
                  "- #{tool_class::Executor::NAME}: #{tool_class::Executor::DESCRIPTION}"
                end.join("\n"),
                user_input: user_input,
                agent_scratchpad: +"",
                conversation: conversation
              }
            end

            def last_conversation
              Cache.new(context.current_user).last_conversation
            end
            strong_memoize_attr :last_conversation

            def conversation
              return [] unless Feature.enabled?(:ai_chat_history_context, context.current_user)

              # include only messages with successful response
              by_request = last_conversation
                .reject { |message| message.error.present? }
                .group_by(&:request_id)
                .select { |_uuid, messages| messages.size > 1 }
              # TODO: we could consider also reorder messages so each request is followed by its response
              by_request.values.flatten.sort_by(&:timestamp)
            end

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                Answer the following questions as best you can. Start with identifying the resource first.
                You have access to the following tools:
                %<tools_definitions>s
                Use the following format:
                Question: the input question you must answer
                Thought: you should always think about what to do
                Action: the action to take, should be one from this list: %<tool_names>s
                Action Input: the input to the action
                Observation: the result of the actions

                ... (this Thought/Action/Action Input/Observation sequence can repeat N times)

                Thought: I know the final answer
                Final Answer: the final answer to the original input question
                REMEMBER to ALWAYS start a line with "Final Answer:" to give me the final answer.

                Begin!
              PROMPT
              ),
              Utils::Prompt.as_assistant("%<agent_scratchpad>s"),
              Utils::Prompt.as_user("Question: %<user_input>s"),
              Utils::Prompt.as_assistant("Thought: ")
            ].freeze
          end
        end
      end
    end
  end
end
