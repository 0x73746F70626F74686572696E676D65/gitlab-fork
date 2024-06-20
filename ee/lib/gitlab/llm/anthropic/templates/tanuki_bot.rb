# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Templates
        class TanukiBot
          OPTIONS = {
            max_tokens: 256
          }.freeze
          CONTENT_ID_FIELD = 'ATTRS'

          MAIN_PROMPT = <<~PROMPT
            Given the following extracted parts of technical documentation enclosed in <quote></quote> XML tags and a question, create a final answer.

            If you know the answer:
              1. answer it
              2. at the end return a %<content_id>s part for references (ALWAYS name it %<content_id>s).

            If you don't know the answer:
              1. just say "I don't know based on the documentation", and don't try to make up an answer
              2. Do not add %<content_id>s part.

            QUESTION: %<question>s

            %<content>s
          PROMPT

          OLD_MAIN_PROMPT = <<~PROMPT
            Given the following extracted parts of technical documentation enclosed in <quote></quote> XML tags and a question, create a final answer.
            If you don't know the answer, just say that you don't know. Don't try to make up an answer.
            At the end of your answer ALWAYS return a "%<content_id>s" part for references and
            ALWAYS name it %<content_id>s.

            QUESTION: %<question>s

            %<content>s
          PROMPT

          def self.final_prompt(user, question:, documents:)
            if Feature.enabled?(:ai_claude_3_for_docs, user)
              claude_3_prompt(question: question, documents: documents)
            else
              prompt(question: question, documents: documents)
            end
          end

          def self.prompt(question:, documents:)
            content = documents_prompt(documents)

            prompt = <<~PROMPT
              \n\nHuman: #{main_prompt(question: question, content: content)}

              Assistant: FINAL ANSWER:
            PROMPT

            {
              method: :completions,
              prompt: prompt,
              options: { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_2_1 }.merge(OPTIONS)
            }
          end

          def self.claude_3_prompt(question:, documents:)
            content = documents_prompt(documents)

            conversation = Gitlab::Llm::Chain::Utils::Prompt.role_conversation([
              Gitlab::Llm::Chain::Utils::Prompt.as_user(main_prompt(question: question,
                content: content)),
              Gitlab::Llm::Chain::Utils::Prompt.as_assistant("FINAL ANSWER:")
            ])

            {
              prompt: conversation,
              options: { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_SONNET }.merge(OPTIONS)
            }
          end

          def self.main_prompt(question:, content:)
            format(
              Feature.enabled?(:ai_doc_tool_hide_reference) ? MAIN_PROMPT : OLD_MAIN_PROMPT, # rubocop:disable Gitlab/FeatureFlagWithoutActor -- reduce code complexity
              question: question,
              content: content,
              content_id: CONTENT_ID_FIELD
            )
          end

          def self.documents_prompt(documents)
            documents.map do |document|
              <<~PROMPT.strip
                <quote>
                CONTENT: #{document[:content]}
                #{CONTENT_ID_FIELD}: CNT-IDX-#{document[:id]}
                </quote>
              PROMPT
            end.join("\n\n")
          end
        end
      end
    end
  end
end
