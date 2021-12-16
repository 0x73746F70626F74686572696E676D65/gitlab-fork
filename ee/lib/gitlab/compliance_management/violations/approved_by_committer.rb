# frozen_string_literal: true

module Gitlab
  module ComplianceManagement
    module Violations
      class ApprovedByCommitter
        REASON = :approved_by_committer

        def initialize(merge_request)
          @merge_request = merge_request
        end

        def execute
          ::MergeRequests::ComplianceViolation.bulk_upsert!(
            violations,
            unique_by: [:merge_request_id, :violating_user_id, :reason],
            batch_size: 100
          )
        end

        private

        def violations
          violating_user_ids.map do |user_id|
            @merge_request.compliance_violations.new(
              violating_user_id: user_id,
              reason: REASON
            )
          end
        end

        def violating_user_ids
          approving_committer_ids.reject { |user_id| existing_violating_user_ids.include?(user_id) }
        end

        # rubocop: disable CodeReuse/ActiveRecord
        def approving_committer_ids
          @merge_request.approver_users.pluck(:id) & @merge_request.committers.pluck(:id)
        end
        # rubocop: enable CodeReuse/ActiveRecord

        # rubocop: disable CodeReuse/ActiveRecord
        def existing_violating_user_ids
          @merge_request.compliance_violations.approved_by_committer.pluck(:violating_user_id)
        end
        # rubocop: enable CodeReuse/ActiveRecord
      end
    end
  end
end
