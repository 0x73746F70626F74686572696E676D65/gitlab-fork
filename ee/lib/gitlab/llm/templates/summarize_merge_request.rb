# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class SummarizeMergeRequest
        include Gitlab::Utils::StrongMemoize

        def initialize(merge_request, mr_diff)
          @merge_request = merge_request
          @mr_diff = mr_diff
        end

        def to_prompt
          return if extracted_diff.blank?

          <<~PROMPT
            You are a code assistant, developed to help summarize code in non-technical terms.

            ```
            #{extracted_diff}
            ```

            The code above, enclosed by three ticks, is the code diff of a merge request.

            Write a summary of the changes in couple sentences, the way an expert engineer would summarize the
            changes using simple - generally non-technical - terms.

            You MUST ensure that it is no longer than 1800 characters. A character is considered anything, not only
            letters.
          PROMPT
        end

        private

        attr_reader :merge_request, :mr_diff

        def extracted_diff
          # Each diff string starts with information about the lines changed,
          #   bracketed by @@. Removing this saves us tokens.
          #
          # Ex: @@ -0,0 +1,58 @@\n+# frozen_string_literal: true\n+\n+module MergeRequests\n+
          #
          mr_diff.raw_diffs.to_a.map do |diff|
            next if diff.diff.encoding != Encoding::UTF_8 || diff.has_binary_notice?

            diff_output(diff.old_path, diff.new_path, diff.diff.sub(Gitlab::Regex.git_diff_prefix, ""))
          end.join.truncate_words(750)
        end
        strong_memoize_attr :extracted_diff

        def diff_output(old_path, new_path, diff)
          <<~DIFF
            --- #{old_path}
            +++ #{new_path}
            #{diff}
          DIFF
        end
      end
    end
  end
end
