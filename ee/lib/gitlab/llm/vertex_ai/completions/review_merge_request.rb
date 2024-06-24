# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Completions
        class ReviewMergeRequest < Gitlab::Llm::Completions::Base
          DRAFT_NOTES_COUNT_LIMIT = 50

          def execute
            # Initialize ivar that will be populated as AI review diff hunks
            @draft_notes_params = []
            mr_diff_refs = merge_request.diff_refs

            merge_request.ai_reviewable_diff_files.each do |diff_file|
              break if draft_notes_limit_reached?

              diff_file.diff_lines_by_hunk.each do |hunk|
                break if draft_notes_limit_reached?

                prompt = generate_prompt(diff_file, hunk)

                next unless prompt.present?

                response = response_for(user, prompt)
                response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(response)

                build_draft_note_params(response_modifier, diff_file, hunk, mr_diff_refs)
              end
            end

            publish_draft_notes
          end

          private

          def merge_request
            resource
          end

          def generate_prompt(diff_file, hunk)
            ai_prompt_class.new(diff_file, hunk).to_prompt
          end

          def response_for(user, prompt)
            ::Gitlab::Llm::VertexAi::Client
              .new(user, unit_primitive: 'review_merge_request', tracking_context: tracking_context)
              .chat(
                content: prompt,
                parameters: ::Gitlab::Llm::VertexAi::Configuration.payload_parameters(temperature: 0)
              )
          end

          def draft_notes_limit_reached?
            @draft_notes_params.size == DRAFT_NOTES_COUNT_LIMIT
          end

          def build_draft_note_params(response_modifier, diff_file, hunk, diff_refs)
            return if response_modifier.errors.any? || response_modifier.response_body.blank?

            # We only need `old_line` if the hunk is all removal as we need to
            # create the note on the old line.
            old_line = hunk[:removed].last&.old_pos if hunk[:added].empty?

            @draft_notes_params << {
              merge_request: merge_request,
              author: Users::Internal.duo_code_review_bot,
              note: response_modifier.response_body,
              position: {
                base_sha: diff_refs.base_sha,
                start_sha: diff_refs.start_sha,
                head_sha: diff_refs.head_sha,
                old_path: diff_file.old_path,
                new_path: diff_file.new_path,
                position_type: 'text',
                old_line: old_line,
                new_line: hunk[:added].last&.new_pos,
                ignore_whitespace_change: false
              }
            }
          end

          def publish_draft_notes
            return if @draft_notes_params.empty?

            draft_notes = @draft_notes_params.map do |draft_note_params|
              DraftNote.new(draft_note_params)
            end

            DraftNote.bulk_insert!(draft_notes, batch_size: 20)
            DraftNotes::PublishService.new(merge_request, Users::Internal.duo_code_review_bot).execute
          end
        end
      end
    end
  end
end
