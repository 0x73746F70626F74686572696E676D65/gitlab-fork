# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Concerns
        module AiDependent
          def prompt
            provider_prompt_class.prompt(prompt_options)
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
                  response: Gitlab::Llm::Chain::StreamedResponseModifier
                              .new(streamed_content(content, chunk), chunk_id: chunk[:id]),
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

          # This method is modified in SingleActionExecutor for Duo Chat
          def streamed_content(content, _chunk)
            content
          end
        end
      end
    end
  end
end
