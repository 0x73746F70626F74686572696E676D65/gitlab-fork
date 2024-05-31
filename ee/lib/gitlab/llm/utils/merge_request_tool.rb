# frozen_string_literal: true

module Gitlab
  module Llm
    module Utils
      class MergeRequestTool
        def self.extract_diff(source_project:, source_branch:, target_project:, target_branch:, character_limit:)
          compare = CompareService
            .new(source_project, source_branch)
            .execute(target_project, target_branch)

          return unless compare

          # Extract only the diff strings and discard everything else
          compare.raw_diffs.to_a.map do |raw_diff|
            # Each diff string starts with information about the lines changed,
            # bracketed by @@. Removing this saves us tokens.
            #
            # Ex: @@ -0,0 +1,58 @@\n+# frozen_string_literal: true\n+\n+module MergeRequests\n+

            next if raw_diff.diff.encoding != Encoding::UTF_8 || raw_diff.has_binary_notice?

            diff_output(raw_diff.old_path, raw_diff.new_path, raw_diff.diff.sub(Gitlab::Regex.git_diff_prefix, ""))
          end.join.truncate_words(character_limit)
        end

        def self.diff_output(old_path, new_path, diff)
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
