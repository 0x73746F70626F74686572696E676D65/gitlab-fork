# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          class Executor
            include Gitlab::Utils::StrongMemoize
            include Concerns::AiDependent
            include Langsmith::RunHelpers

            attr_reader :tools, :user_input, :context, :response_handler
            attr_accessor :iterations

            AGENT_NAME = 'GitLab Duo Chat'
            MAX_ITERATIONS = 10
            RESPONSE_TYPE_TOOL = 'tool'

            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic
            }.freeze

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
              MAX_ITERATIONS.times do
                thought = execute_streamed_request

                answer = Answer.from_response(response_body: "Thought: #{thought}", tools: tools, context: context)

                return answer if answer.is_final?

                options[:agent_scratchpad] << "\nThought: #{answer.suggestions}"
                options[:agent_scratchpad] << answer.content.to_s

                tool_class = answer.tool

                picked_tool_action(tool_class)

                tool = tool_class.new(
                  context: context,
                  options: {
                    input: user_input,
                    suggestions: options[:agent_scratchpad]
                  },
                  stream_response_handler: stream_response_handler
                )

                tool_answer = tool.execute

                return tool_answer if tool_answer.is_final?

                options[:agent_scratchpad] << "Observation: #{tool_answer.content}\n"
              end

              Answer.default_final_answer(context: context)
            rescue Net::ReadTimeout => error
              Gitlab::ErrorTracking.track_exception(error)
              Answer.error_answer(
                context: context,
                content: _("I'm sorry, I couldn't respond in time. Please try again."),
                error_code: 'A1000'
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

            def execute_streamed_request
              request(&streamed_request_handler(StreamedZeroShotAnswer.new))
            end

            attr_reader :logger, :stream_response_handler

            # This method should not be memoized because the input variables change over time
            def base_prompt
              Utils::Prompt.no_role_text(PROMPT_TEMPLATE, options)
            end

            def options
              @options ||= {
                tool_names: tools.map { |tool_class| tool_class::Executor::NAME }.join(', '),
                tools_definitions: tools.map do |tool_class|
                  tool_class::Executor.full_definition
                end.join("\n"),
                user_input: user_input,
                agent_scratchpad: +"",
                conversation: conversation,
                prompt_version: prompt_version,
                zero_shot_prompt: zero_shot_prompt,
                system_prompt: context.agent_version&.prompt,
                current_resource: current_resource,
                source_template: source_template,
                current_code: current_code,
                resources: available_resources_names
              }
            end

            def picked_tool_action(tool_class)
              logger.info(message: "Picked tool", tool: tool_class.to_s)

              response_handler.execute(
                response: Gitlab::Llm::Chain::ToolResponseModifier.new(tool_class),
                options: { role: ::Gitlab::Llm::AiMessage::ROLE_SYSTEM,
                           type: RESPONSE_TYPE_TOOL }
              )

              # We need to stream the response for clients that already migrated to use `ai_action` and no longer
              # use `resource_id` as an identifier. Once streaming is enabled and all clients migrated, we can
              # remove the `response_handler` call above.
              return unless stream_response_handler

              stream_response_handler.execute(
                response: Gitlab::Llm::Chain::ToolResponseModifier.new(tool_class),
                options: {
                  role: ::Gitlab::Llm::ChatMessage::ROLE_SYSTEM,
                  type: RESPONSE_TYPE_TOOL
                }
              )
            end

            def available_resources_names
              tools.filter_map do |tool_class|
                tool_class::Executor::RESOURCE_NAME.pluralize if tool_class::Executor::RESOURCE_NAME.present?
              end.join(', ')
            end
            strong_memoize_attr :available_resources_names

            def prompt_version
              return CUSTOM_AGENT_PROMPT_TEMPLATE if context.agent_version

              PROMPT_TEMPLATE
            end

            def zero_shot_prompt
              ZERO_SHOT_PROMPT
            end

            def last_conversation
              ChatStorage.new(context.current_user, context.agent_version&.id).last_conversation
            end
            strong_memoize_attr :last_conversation

            def conversation
              # include only messages with successful response and reorder
              # messages so each question is followed by its answer
              by_request = last_conversation
                .reject { |message| message.errors.present? }
                .group_by(&:request_id)
                .select { |_uuid, messages| messages.size > 1 }

              by_request.values.sort_by { |messages| messages.first.timestamp }.flatten
            end

            def current_code
              file_context = current_file_context
              return provider_prompt_class.current_selection_prompt(file_context) if file_context

              blob = @context.extra_resource[:blob]
              return "" unless blob

              provider_prompt_class.current_blob_prompt(blob)
            end

            def current_file_context
              return unless context.current_file[:selected_text].present?

              context.current_file
            end

            def prompt_options
              options
            end

            def current_resource
              context.current_page_short_description
            rescue ArgumentError
              ""
            end

            def source_template
              <<~CONTEXT
                  If GitLab resource of issue or epic type is present and is directly relevant to the question,
                  include the following section at the end of your response:
                  'Sources:' followed by the corresponding GitLab resource link named after the title of the resource.
                  Format the link using Markdown syntax ([title](link)) for it to be clickable.
              CONTEXT
            end

            ZERO_SHOT_PROMPT = <<~PROMPT.freeze
                  Answer the question as accurate as you can.

                  You have access only to the following tools:
                  <tool_list>
                  %<tools_definitions>s
                  </tool_list>
                  Consider every tool before making a decision.
                  Ensure that your answer is accurate and contain only information directly supported by the information retrieved using provided tools.

                  When you can answer the question directly you must use this response format:
                  Thought: you should always think about how to answer the question
                  Action: DirectAnswer
                  Final Answer: the final answer to the original input question if you have a direct answer to the user's question.

                  You must always use the following format when using a tool:
                  Question: the input question you must answer
                  Thought: you should always think about what to do
                  Action: the action to take, should be one tool from this list: [%<tool_names>s]
                  Action Input: the input to the action needs to be provided for every action that uses a tool.
                  Observation: the result of the tool actions. But remember that you're still #{AGENT_NAME}.


                  ... (this Thought/Action/Action Input/Observation sequence can repeat N times)

                  Thought: I know the final answer.
                  Final Answer: the final answer to the original input question.

                  When concluding your response, provide the final answer as "Final Answer:". It should contain everything that user needs to see, including answer from "Observation" section.
                  %<current_code>s

                  You have access to the following GitLab resources: %<resources>s.
                  You also have access to all information that can be helpful to someone working in software development of any kind.
                  At the moment, you do not have access to the following GitLab resources: Merge Requests, Pipelines, Vulnerabilities.
                  At the moment, you do not have the ability to search Issues or Epics based on a description or keywords. You can only read information about a specific issue/epic IF the user is on the specific issue/epic's page, or provides a URL or ID.
                  Do not use the IssueReader or EpicReader tool if you do not have these specified identifiers.

                  %<source_template>s

                  Ask user to leave feedback.

                  %<current_resource>s

                  Begin!
            PROMPT

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(ZERO_SHOT_PROMPT),
              Utils::Prompt.as_user("Question: %<user_input>s"),
              # We're explicitly adding "\n" before the `Assistant:` in order to avoid the Anthropic API error
              # `prompt must end with "\n\nAssistant:" turn`.
              # See https://gitlab.com/gitlab-org/gitlab/-/issues/435911 for more information.
              Utils::Prompt.as_assistant("\nAssistant: %<agent_scratchpad>s"),
              Utils::Prompt.as_assistant("Thought: ")
            ].freeze

            CUSTOM_AGENT_PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                    You must always use the following format:
                    Question: the input question you must answer
                    Thought: you should always think about what to do
                    Action: the action to take, should be one tool from this list or a direct answer (then use DirectAnswer as action): [%<tool_names>s]
                    Action Input: the input to the action needs to be provided for every action that uses a tool
                    Observation: the result of the actions. If the Action is DirectAnswer never write an Observation, but remember that you're still #{AGENT_NAME}.

                    ... (this Thought/Action/Action Input/Observation sequence can repeat N times)

                    Thought: I know the final answer.
                    Final Answer: the final answer to the original input question.

                    When concluding your response, provide the final answer as "Final Answer:" as soon as the answer is recognized.

                    Begin!
                PROMPT
              ),
              Utils::Prompt.as_user("Question: %<user_input>s"),
              Utils::Prompt.as_assistant("Thought: ")
            ].freeze
          end
        end
      end
    end
  end
end
