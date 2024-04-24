# frozen_string_literal: true

module EE
  module Types
    module MergeRequestType
      extend ActiveSupport::Concern

      prepended do
        field :approvals_left, GraphQL::Types::Int,
          null: true, calls_gitaly: true,
          description: 'Number of approvals left.'

        field :approvals_required, GraphQL::Types::Int,
          null: true, description: 'Number of approvals required.'

        field :merge_trains_count, GraphQL::Types::Int,
          null: true,
          description: 'Number of merge requests in the merge train.'

        field :has_security_reports, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :has_security_reports?,
          description: 'Indicates if the source branch has any security reports.'

        field :security_reports_up_to_date_on_target_branch, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :security_reports_up_to_date?,
          description: 'Indicates if the target branch security reports are out of date.'

        field :approval_state, ::Types::MergeRequests::ApprovalStateType,
          null: false,
          description: 'Information relating to rules that must be satisfied to merge this merge request.'

        field :suggested_reviewers, ::Types::AppliedMl::SuggestedReviewersType,
          null: true,
          alpha: { milestone: '15.4' },
          description: 'Suggested reviewers for merge request.' \
                       ' Returns `null` if `suggested_reviewers` feature flag is disabled.' \
                       ' This flag is disabled by default and only available on GitLab.com' \
                       ' because the feature is experimental and is subject to change without notice.'

        field :blocking_merge_requests, ::Types::MergeRequests::BlockingMergeRequestsType,
          null: true,
          alpha: { milestone: '16.5' },
          description: 'Merge requests that block another merge request from merging.',
          resolver_method: :base_merge_request # processing is done in the GraphQL type

        field :merge_request_diffs, ::Types::MergeRequestDiffType.connection_type,
          null: true,
          alpha: { milestone: '16.2' },
          extras: [:lookahead],
          description: 'Diff versions of a merge request'

        field :finding_reports_comparer,
          type: ::Types::Security::FindingReportsComparerType,
          null: true,
          alpha: { milestone: '16.1' },
          description: 'Vulnerability finding reports comparison reported on the merge request.',
          resolver: ::Resolvers::SecurityReport::FindingReportsComparerResolver

        field :policy_violations,
          type: ::Types::SecurityOrchestration::PolicyViolationDetailsType,
          null: true,
          alpha: { milestone: '17.0' },
          description: 'Policy violations reported on the merge request. ' \
                       'Returns `null` if `save_policy_violation_data` feature flag is disabled.',
          resolver: ::Resolvers::SecurityOrchestration::PolicyViolationsResolver
      end

      def merge_trains_count
        return unless object.target_project.merge_trains_enabled?

        object.merge_train.car_count
      end

      def suggested_reviewers
        return unless object.project.can_suggest_reviewers?

        object.predictions
      end

      def base_merge_request
        object
      end

      # rubocop:disable CodeReuse/ActiveRecord
      # Cop is disabled because we only want to call `includes` in this class.
      def merge_request_diffs(lookahead:)
        # We include `merge_request` by default because of policy check in `MergeRequestDiffType`
        # which can result to N+1.
        includes = [:merge_request]

        selects_review_llm_summaries =
          lookahead.selection(:nodes).selects?(:review_llm_summaries) ||
          lookahead.selection(:edges).selection(:node).selects?(:review_llm_summaries)

        includes << [merge_request_review_llm_summaries: [:user, { review: [:author] }]] if selects_review_llm_summaries

        object.merge_request_diffs.includes(includes)
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def mergeable
        lazy_committers { object.mergeable? }
      end

      def detailed_merge_status
        lazy_committers { super }
      end

      private

      def lazy_committers
        # No need to batch load committers and lazy load if we allow committers
        # to approve since we're not going to filter committers so we can return
        # early.
        return yield unless object.merge_requests_disable_committers_approval?

        object.commits.add_committers_to_batch_loader(with_merge_commits: true)
        ::Gitlab::Graphql::Lazy.new do
          yield
        end
      end
    end
  end
end
