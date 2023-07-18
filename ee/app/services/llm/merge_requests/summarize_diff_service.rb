# frozen_string_literal: true

module Llm
  module MergeRequests
    class SummarizeDiffService
      GIT_DIFF_PREFIX_REGEX = /\A@@( -\d+,\d+ \+\d+,\d+ )@@/

      def initialize(title:, user:, diff:)
        @title = title
        @user = user
        @diff = diff
      end

      def execute
        return unless self.class.enabled?(user: user,
          group: diff.merge_request.project.root_ancestor) && user.can?(:generate_diff_summary,
            diff.merge_request)

        response_modifier.new(response).response_body.presence
      end

      def self.enabled?(user:, group:)
        Feature.enabled?(:openai_experimentation, user) &&
          Gitlab::Llm::StageCheck.available?(group, :summarize_diff) &&
          ::License.feature_available?(:summarize_mr_changes)
      end

      def self.vertex_ai?(project)
        Feature.enabled?(:summarize_diff_vertex, project)
      end

      private

      attr_reader :title, :user, :diff

      def prompt
        <<~PROMPT
          You are a code assistant, developed to help summarize code in non-technical terms.

          ```
          #{extracted_diff}
          ```

          The code above, enclosed by three ticks, is the code diff of a merge request. The merge request's
          title is: '#{title}'

          Write a summary of the changes in couple sentences, the way an expert engineer would summarize the
          changes using simple - generally non-technical - terms.
        PROMPT
      end

      def summary_message
        prompt
      end

      def diff_output(old_path, new_path, diff)
        <<~DIFF
          --- #{old_path}
          +++ #{new_path}
          #{diff}
        DIFF
      end

      def extracted_diff
        # Each diff string starts with information about the lines changed,
        #   bracketed by @@. Removing this saves us tokens.
        #
        # Ex: @@ -0,0 +1,58 @@\n+# frozen_string_literal: true\n+\n+module MergeRequests\n+
        #
        diff.raw_diffs.to_a.map do |diff|
          diff_output(diff.old_path, diff.new_path, diff.diff.sub(GIT_DIFF_PREFIX_REGEX, ""))
        end.join.truncate_words(2000)
      end

      def response_modifier
        if self.class.vertex_ai?(diff.merge_request.project)
          ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions
        else
          ::Gitlab::Llm::OpenAi::ResponseModifiers::Chat
        end
      end

      def response
        if self.class.vertex_ai?(diff.merge_request.project)
          Gitlab::Llm::VertexAi::Client.new(user).text(content: summary_message)
        else
          Gitlab::Llm::OpenAi::Client.new(user).chat(content: summary_message, moderated: true)
        end
      end
    end
  end
end

Llm::MergeRequests::SummarizeDiffService.prepend_mod
