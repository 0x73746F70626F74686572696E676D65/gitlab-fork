# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class Tool
          include Gitlab::Utils::StrongMemoize
          include Langsmith::RunHelpers

          NAME = 'Base Tool'
          DESCRIPTION = 'Base Tool description'
          EXAMPLE = 'Example description'

          attr_reader :context, :options

          delegate :resource, :resource=, to: :context

          def self.full_definition
            [
              "<tool>",
              "<tool_name>#{self::NAME}</tool_name>",
              "<description>",
              description,
              "</description>",
              "<example>",
              self::EXAMPLE,
              "</example>",
              "</tool>"
            ].join("\n")
          end

          def initialize(context:, options:, stream_response_handler: nil, command: nil)
            @context = context
            @options = options
            @logger = Gitlab::Llm::Logger.build
            @stream_response_handler = stream_response_handler
            @command = command
          end

          def execute(&block)
            return already_used_answer if already_used?
            return not_found unless authorize

            perform(&block)
          end

          def authorize
            raise NotImplementedError
          end

          def perform
            raise NotImplementedError
          end

          def current_resource?(resource_identifier_type, resource_name)
            resource_identifier_type == 'current' && context.resource.class.name.downcase == resource_name
          end

          def projects_from_context
            case context.container
            when Project
              [context.container]
            when Namespaces::ProjectNamespace
              [context.container.project]
            when Group
              context.container.all_projects
            end
          end
          strong_memoize_attr :projects_from_context

          def group_from_context
            case context.container
            when Group
              context.container
            when Project
              context.container.group
            when Namespaces::ProjectNamespace
              context.container.parent
            end
          end
          strong_memoize_attr :group_from_context

          private

          attr_reader :logger, :stream_response_handler

          def self.description
            self::DESCRIPTION
          end

          def not_found
            content = "I'm sorry, I can't generate a response. You might want to try again. " \
              "You could also be getting this error because the items you're asking about " \
              "either don't exist, you don't have access to them, or your session has expired."

            Answer.error_answer(context: context, content: content, error_code: "M3003")
          end

          def error_with_message(content)
            Answer.error_answer(context: context, content: content)
          end

          def already_used_answer
            content = "You already have the answer from #{self.class::NAME} tool, read carefully."

            logger.info_or_debug(context.current_user, message: "Answer", class: self.class.to_s, content: content)

            ::Gitlab::Llm::Chain::Answer.new(
              status: :not_executed, context: context, content: content, tool: nil, is_final: false
            )
          end

          # track tool usage to avoid cycling through same tools multiple times
          def already_used?
            cls = self.class

            if context.tools_used.include?(cls)
              # detect tool cycling for specific types of questions
              logger.info(message: "Tool cycling detected")
              return true
            end

            context.tools_used << cls

            false
          end

          def prompt_options
            options
          end
        end
      end
    end
  end
end
