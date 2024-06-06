# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          class Executor < Tool
            include Concerns::AiDependent

            NAME = "SummarizeComments"
            DESCRIPTION = "This tool is useful when you need to create a summary of all notes, " \
                          "comments or discussions on a given, identified resource."
            EXAMPLE =
              <<~PROMPT
                  Question: Please summarize the http://gitlab.example/ai/test/-/issues/1 issue in the bullet points
                  Picked tools: First: "IssueReader" tool, second: "SummarizeComments" tool.
                  Reason: There is issue identifier in the question, so you need to use "IssueReader" tool.
                  Once the issue is identified, you should use "SummarizeComments" tool to summarize the issue.
                  For the final answer, please rewrite it into the bullet points.
              PROMPT

            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::VertexAi
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are an assistant that extracts the most important information from the comments in maximum 10 bullet points.
                  Each comment is wrapped in a <comment> tag.

                  %<notes_content>s

                  Desired markdown format:
                  **<summary_title>**
                  - <bullet_point>
                  - <bullet_point>
                  - <bullet_point>
                  - ...

                  Focus on extracting information related to one another and that are the majority of the content.
                  Ignore phrases that are not connected to others.
                  Do not specify what you are ignoring.
                  Do not answer questions.
                PROMPT
              )
            ].freeze

            def perform(&block)
              notes = NotesFinder.new(context.current_user, target: resource).execute.by_humans

              content = if notes.exists?
                          notes_content = notes_to_summarize(notes) # rubocop: disable CodeReuse/ActiveRecord
                          options[:notes_content] = notes_content

                          if options[:raw_ai_response]
                            request(&block)
                          else
                            build_answer(resource, request)
                          end
                        else
                          "#{resource_name} ##{resource.iid} has no comments to be summarized."
                        end

              logger.info_or_debug(context.current_user, message: "Answer", class: self.class.to_s, content: content)

              ::Gitlab::Llm::Chain::Answer.new(
                status: :ok, context: context, content: content, tool: nil, is_final: false
              )
            end
            traceable :perform, run_type: 'tool'

            private

            def notes_to_summarize(notes)
              notes_content = +""
              input_content_limit = provider_prompt_class::MAX_CHARACTERS - PROMPT_TEMPLATE.size
              notes.each_batch do |batch|
                batch.pluck(:id, :note).each do |note| # rubocop: disable CodeReuse/ActiveRecord
                  input_content_limit = provider_prompt_class::MAX_CHARACTERS

                  break notes_content if notes_content.size + note[1].size >= input_content_limit

                  notes_content << (format("<comment>%<note>s</comment>", note: note[1]))
                end
              end

              notes_content
            end

            def can_summarize?
              logger.info_or_debug(context.current_user, message: "Supported Issuable Typees Ability Allowed",
                content: Ability.allowed?(context.current_user, :summarize_comments, context.resource))

              ::Llm::GenerateSummaryService::SUPPORTED_ISSUABLE_TYPES.include?(resource.to_ability_name) &&
                Ability.allowed?(context.current_user, :summarize_comments, context.resource)
            end

            def authorize
              can_summarize? && ::Gitlab::Llm::Utils::Authorizer
                                  .resource(resource: context.resource, user: context.current_user).allowed?
            end

            def build_answer(resource, ai_response)
              [
                "Here is the summary for #{resource_name} ##{resource.iid} comments:",
                ai_response.to_s
              ].join("\n")
            end

            def already_used_answer
              content = "You already have the summary of the notes, comments, discussions for the " \
                        "#{resource_name} ##{resource.iid} in your context, read carefully."

              ::Gitlab::Llm::Chain::Answer.new(
                status: :not_executed, context: context, content: content, tool: nil, is_final: false
              )
            end

            def resource
              @resource ||= context.resource
            end

            def resource_name
              @resource_name ||= resource.to_ability_name.humanize
            end
          end
        end
      end
    end
  end
end
