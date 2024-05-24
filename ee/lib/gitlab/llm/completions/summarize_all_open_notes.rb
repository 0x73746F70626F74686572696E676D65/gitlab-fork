# frozen_string_literal: true

module Gitlab
  module Llm
    module Completions
      class SummarizeAllOpenNotes < Gitlab::Llm::Completions::Base
        def execute
          return unless user
          return unless issuable

          context = ::Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: issuable.resource_parent,
            resource: issuable,
            ai_request: ai_provider_request(user)
          )

          streamed_answer = Gitlab::Llm::Chain::StreamedAnswer.new

          answer = ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor.new(
            context: context, options: { raw_ai_response: true }
          ).execute do |content|
            chunk = streamed_answer.next_chunk(content)
            next unless chunk

            send_chunk(context, chunk)
          end
          response_modifier = Gitlab::Llm::ResponseModifiers::ToolAnswer.new({ content: answer.content }.to_json)

          ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
            user, issuable, response_modifier, options: response_options
          ).execute

          response_modifier
        end

        private

        def ai_provider_request(user)
          if Feature.enabled?(:summarize_notes_with_anthropic, user)
            ::Gitlab::Llm::Chain::Requests::Anthropic.new(user,
              unit_primitive: 'summarize_issue_discussions', tracking_context: tracking_context)
          else
            ::Gitlab::Llm::Chain::Requests::VertexAi.new(user,
              unit_primitive: 'summarize_issue_discussions', tracking_context: tracking_context)
          end
        end

        def issuable
          resource
        end
      end
    end
  end
end
