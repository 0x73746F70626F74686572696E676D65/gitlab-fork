# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      class Answer
        extend Langsmith::RunHelpers

        attr_accessor :status, :content, :context, :tool, :suggestions, :is_final, :extras, :error_code
        alias_method :is_final?, :is_final

        def self.from_response(response_body:, tools:, context:, parser_klass: Parsers::ChainOfThoughtParser)
          parser = parser_klass.new(output: response_body)
          parser.parse

          return final_answer(context: context, content: parser.final_answer) if parser.final_answer

          executor = nil
          action = parser.action
          action_input = parser.action_input
          thought = parser.thought
          content = "\nAction: #{action}\nAction Input: #{action_input}\n"

          if tools.present?
            tool = tools.find { |tool_class| tool_class::Executor::NAME == action }
            executor = tool::Executor if tool

            return default_final_answer(context: context) unless tool
          end

          logger.info_or_debug(context.current_user, message: "Answer", content: content)

          new(
            status: :ok,
            context: context,
            content: content,
            tool: executor,
            suggestions: thought,
            is_final: false
          )
        end
        traceable :from_response, name: 'Get answer from response', run_type: 'parser', class_method: true

        def self.final_answer(context:, content:, extras: nil)
          logger.info_or_debug(context.current_user, message: "Final answer", content: content)

          new(
            status: :ok,
            context: context,
            content: content,
            tool: nil,
            suggestions: nil,
            is_final: true,
            extras: extras
          )
        end

        def self.default_final_answer(context:)
          logger.info_or_debug(context.current_user, message: "Default final answer", error_code: "A6000")

          track_event(context, 'default_answer')

          final_answer(context: context, content: default_final_message)
        end

        def self.default_final_message
          s_("AI|I'm sorry, I couldn't respond in time. " \
            "Please try a more specific request or enter /clear to start a new chat.")
        end

        def self.error_answer(context:, error_code: nil, content: default_error_answer)
          logger.error(message: "Error", error: content, error_code: error_code)
          track_event(context, 'error_answer')

          new(
            status: :error,
            content: content,
            context: context,
            tool: nil,
            is_final: true,
            error_code: error_code
          )
        end

        def self.default_error_answer
          s_("AI|I'm sorry, I can't generate a response. Please try again.")
        end

        def initialize(
          status:, context:, content:, tool:, suggestions: nil, is_final: false, extras: nil,
          error_code: nil)
          @status = status
          @context = context
          @content = content
          @tool = tool
          @suggestions = suggestions
          @is_final = is_final
          @extras = extras
          @error_code = error_code
        end

        private_class_method def self.logger
          Gitlab::Llm::Logger.build
        end

        private_class_method def self.track_event(context, action)
          Gitlab::Tracking.event(
            Gitlab::Llm::Chain::Answer.to_s,
            action,
            label: 'gitlab_duo_chat_answer',
            property: context.request_id,
            namespace: context.container,
            user: context.current_user
          )
        end
      end
    end
  end
end
