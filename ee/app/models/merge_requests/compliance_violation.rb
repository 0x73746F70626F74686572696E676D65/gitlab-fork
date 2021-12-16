# frozen_string_literal: true

module MergeRequests
  class ComplianceViolation < ApplicationRecord
    include BulkInsertSafe

    self.table_name = 'merge_requests_compliance_violations'

    # Reasons are defined by GitLab in our public documentation.
    # https://docs.gitlab.com/ee/user/compliance/compliance_dashboard/#approval-status-and-separation-of-duties
    enum reason: {
      ::Gitlab::ComplianceManagement::Violations::ApprovedByMergeRequestAuthor::REASON => 0,
      ::Gitlab::ComplianceManagement::Violations::ApprovedByCommitter::REASON => 1,
      ::Gitlab::ComplianceManagement::Violations::ApprovedByInsufficientUsers::REASON => 2
    }

    scope :approved_by_committer, -> { where(reason: ::Gitlab::ComplianceManagement::Violations::ApprovedByCommitter::REASON) }

    belongs_to :violating_user, class_name: 'User'
    belongs_to :merge_request

    validates :violating_user, presence: true
    validates :merge_request,
              presence: true,
              uniqueness: {
                scope: [:violating_user, :reason],
                message: -> (_object, _data) { _('compliance violation has already been recorded') }
              }
    validates :reason, presence: true

    VIOLATIONS = [
      ::Gitlab::ComplianceManagement::Violations::ApprovedByMergeRequestAuthor,
      ::Gitlab::ComplianceManagement::Violations::ApprovedByCommitter,
      ::Gitlab::ComplianceManagement::Violations::ApprovedByInsufficientUsers
    ].freeze

    def self.process_merge_request(merge_request)
      VIOLATIONS.each do |violation_check|
        violation_check.new(merge_request).execute
      end
    end
  end
end
