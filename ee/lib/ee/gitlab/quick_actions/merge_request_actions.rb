# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module MergeRequestActions
        extend ActiveSupport::Concern
        include ::Gitlab::QuickActions::Dsl

        included do
          desc { _('Change reviewers') }
          explanation { _('Change reviewers.') }
          execution_message { _('Changed reviewers.') }
          params '@user1 @user2'
          types MergeRequest
          condition do
            quick_action_target.allows_multiple_reviewers? &&
              quick_action_target.persisted? &&
              current_user.can?(:"admin_#{quick_action_target.to_ability_name}", project)
          end
          command :reassign_reviewer do |reassign_param|
            @updates[:reviewer_ids] = extract_users(reassign_param).map(&:id)
          end

          desc { _('Create LLM-generated summary from diff(s)') }
          explanation { _('Creates a LLM-generated summary from diff(s).') }
          execution_message { _('Request for summary queued.') }
          types MergeRequest
          condition do
            ::Feature.enabled?(:summarize_diff_quick_action, current_user) &&
              ::Llm::MergeRequests::SummarizeDiffService.enabled?(
                group: quick_action_target.project.root_ancestor,
                user: current_user
              )
          end
          command :summarize_diff do
            ::MergeRequests::Llm::SummarizeMergeRequestWorker.new.perform(
              current_user.id,
              { 'type' => ::MergeRequests::Llm::SummarizeMergeRequestWorker::SUMMARIZE_QUICK_ACTION,
                'merge_request_id' => quick_action_target.id }
            )
          end
        end
      end
    end
  end
end
