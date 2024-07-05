# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Utils::StrongMemoize

        def initialize(diff_file, hunk)
          @diff_file = diff_file
          @hunk = hunk
        end

        def to_prompt
          return if truncated_raw_diff.blank?

          <<~PROMPT
Git diff of `#{diff_file.new_path}`:
```
#{truncated_raw_diff}
```

New hunk of `#{diff_file.new_path}`:
```
#{generate_hunk_lines(hunk[:added], :new_pos)}
```

Old hunk of `#{diff_file.new_path}`:
```
#{generate_hunk_lines(hunk[:removed], :old_pos)}
```

Instructions:
- Review new hunk and old hunk of `#{diff_file.new_path}` line by line. New and old hunks are annotated with line numbers. The new hunk will replace the old hunk.
- Use git diff of `#{diff_file.new_path}` only for additional context.
- Skip empty new Hunk and old Hunk during your review.
- You must only make really helpful suggestions based on your review.
- If needed, provide really helpful code suggestions using fenced code blocks and include in your suggestions.
- Code suggestions must be complete and correctly formatted without line numbers.
- Your response must only include your really helpful suggestions and must not include mentions of git diff, new hunk and old hunk.

Response:
          PROMPT
        end

        private

        attr_reader :diff_file, :hunk

        def generate_hunk_lines(lines, pos)
          lines.map do |line|
            line_number = pos == :new_pos ? line.new_pos : line.old_pos

            # We remove the + and - sign from the diff line since it can confuse
            # the LLM.
            text = line.text[1..]
            "#{line_number}: #{text}".chomp
          end.join("\n")
        end

        def truncated_raw_diff
          diff_file.raw_diff.sub(Gitlab::Regex.git_diff_prefix, "").truncate_words(750)
        end
        strong_memoize_attr :truncated_raw_diff
      end
    end
  end
end
