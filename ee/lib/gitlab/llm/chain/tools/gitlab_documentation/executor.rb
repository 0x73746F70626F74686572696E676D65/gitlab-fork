# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module GitlabDocumentation
          class Executor < Tool
            NAME = 'GitlabDocumentation'
            HUMAN_NAME = 'GitLab Documentation'
            RESOURCE_NAME = 'documentation answer'
            DESCRIPTION =
              <<~PROMPT
                This tool is beneficial when you need to answer questions concerning GitLab and its features.
                Questions can be about GitLab's projects, groups, issues, merge requests,
                epics, milestones, labels, CI/CD pipelines, git repositories, and more.
              PROMPT

            EXAMPLE =
              <<~PROMPT
                Question: How do I set up a new project?
                Thought: Question is about inner working of GitLab. "GitlabDocumentation" tool is the right one for
                  the job.
                Action: GitlabDocumentation
                Action Input: How do I set up a new project?
              PROMPT

            def perform(&_block)
              # We can't reuse the injected client here but need to call TanukiBot as it uses the
              # embedding database and calls the VertexAI text embeddings API endpoint internally.
              logger.info(message: "Calling TanukiBot", class: self.class.to_s)
              streamed_answer = StreamedDocumentationAnswer.new

              response_modifier = Gitlab::Llm::TanukiBot.new(
                current_user: context.current_user,
                question: options[:input],
                tracking_context: { action: 'chat_documentation' }
              ).execute do |content|
                next unless stream_response_handler

                chunk = streamed_answer.next_chunk(content)

                if chunk
                  stream_response_handler.execute(
                    response: Gitlab::Llm::Chain::StreamedResponseModifier.new(content, chunk_id: chunk[:id]),
                    options: { chunk_id: chunk[:id] }
                  )
                end
              end

              Gitlab::Llm::Chain::Answer.final_answer(context: context,
                content: response_modifier.response_body,
                extras: response_modifier.extras
              )
            end
            traceable :perform, run_type: 'tool'

            private

            def authorize
              # Every user with access to a paid namespace that supports AI features has access to
              # the documentation tool.
              Utils::ChatAuthorizer.user(user: context.current_user).allowed?
            end

            def resource_name
              RESOURCE_NAME
            end
          end
        end
      end
    end
  end
end
