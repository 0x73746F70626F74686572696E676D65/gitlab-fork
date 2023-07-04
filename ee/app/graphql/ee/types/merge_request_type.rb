# frozen_string_literal: true

module EE
  module Types
    module MergeRequestType
      extend ActiveSupport::Concern

      prepended do
        field :approved, GraphQL::Types::Boolean,
          method: :approved?,
          null: false, calls_gitaly: true,
          description: 'Indicates if the merge request has all the required approvals. Returns true if no ' \
                       'required approvals are configured.'

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

        field :diff_llm_summaries, ::Types::MergeRequests::DiffLlmSummaryType.connection_type,
          null: true,
          alpha: { milestone: '16.1' },
          description: 'Diff summaries generated by AI'

        field :finding_reports_comparer,
          type: ::Types::Security::FindingReportsComparerType,
          null: true,
          alpha: { milestone: '16.1' },
          description: 'Vulnerability finding reports comparison reported on the merge request.',
          resolver: ::Resolvers::SecurityReport::FindingReportsComparerResolver
      end

      def merge_trains_count
        return unless object.target_project.merge_trains_enabled?

        object.train.car_count
      end

      def suggested_reviewers
        return unless object.project.can_suggest_reviewers?

        object.predictions
      end
    end
  end
end
