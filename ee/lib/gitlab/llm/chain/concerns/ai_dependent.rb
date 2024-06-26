# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Concerns
        module AiDependent
          def prompt
            if claude_3_enabled? && provider_prompt_class.respond_to?(:claude_3_prompt)
              provider_prompt_class.claude_3_prompt(prompt_options)
            else
              provider_prompt_class.prompt(prompt_options)
            end
          end

          def claude_3_enabled?
            Feature.enabled?(:ai_claude_3_ci_editor, context.current_user)
          end

          def request(&block)
            prompt_str = prompt
            prompt_text = prompt_str[:prompt]

            logger.info_or_debug(context.current_user, message: "Prompt", class: self.class.to_s, prompt: prompt_text)

            ai_request.request(prompt_str, unit_primitive: unit_primitive, &block)
          end

          def streamed_request_handler(streamed_answer)
            proc do |content|
              next unless stream_response_handler

              chunk = streamed_answer.next_chunk(content)

              if chunk
                stream_response_handler.execute(
                  response: Gitlab::Llm::Chain::StreamedResponseModifier.new(content, chunk_id: chunk[:id]),
                  options: { chunk_id: chunk[:id] }
                )
              end
            end
          end

          private

          def ai_request
            context.ai_request
          end

          def provider_prompt_class
            ai_provider_name = ai_request.class.name.demodulize.underscore.to_sym

            self.class::PROVIDER_PROMPT_CLASSES[ai_provider_name]
          end

          def unit_primitive
            nil
          end
        end
      end
    end
  end
end
