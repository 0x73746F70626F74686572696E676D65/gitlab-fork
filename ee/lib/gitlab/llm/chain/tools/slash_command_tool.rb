# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class SlashCommandTool < Tool
          extend ::Gitlab::Utils::Override

          def perform
            content = request(&streamed_request_handler(StreamedAnswer.new))

            Answer.new(status: :ok, context: context, content: content, tool: nil)
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e)

            Answer.error_answer(
              context: context,
              error_code: "M4000"
            )
          end
          traceable :perform, run_type: 'tool'

          private

          attr_reader :command

          override :prompt_options
          def prompt_options
            super.merge(command_options).merge(selected_text_options)
          end

          def selected_text_options
            {
              selected_text: context.current_file[:selected_text].to_s,
              file_content: file_content,
              language_info: language_info
            }
          end

          def command_options
            return {} unless command

            command.prompt_options
          end

          def file_content
            content = trimmed_content
            return '' unless content

            partial = content[:is_trimmed] ? 'a part of ' : ''

            <<~TEXT
              Here is #{partial}the content of the file user is working with:
              <file>
                #{content[:content]}
              </file>
            TEXT
          end

          def trimmed_content
            file = context.current_file
            return unless file[:content_above_cursor].present? || file[:content_below_cursor].present?

            max_size = provider_prompt_class::MAX_CHARACTERS / 10
            above = file[:content_above_cursor].to_s.last(max_size)
            below = file[:content_below_cursor].to_s.first(max_size - above.size)
            is_trimmed = above.size < file[:content_above_cursor].to_s.size ||
              below.size < file[:content_below_cursor].to_s.size

            {
              content: "#{above}#{file[:selected_text]}#{below}",
              is_trimmed: is_trimmed
            }
          end

          def filename
            context.current_file[:file_name].to_s
          end

          def language_info
            language = ::CodeSuggestions::ProgrammingLanguage.detect_from_filename(filename)
            return '' unless language.name.present?

            "The code is written in #{language.name} and stored as #{filename}"
          end
        end
      end
    end
  end
end
