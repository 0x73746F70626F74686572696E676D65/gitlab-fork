# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class GeneratePolicyViolationCommentService
      include ::Gitlab::ExclusiveLeaseHelpers
      include ::Gitlab::Utils::StrongMemoize

      LOCK_SLEEP_SEC = 0.5.seconds

      attr_reader :merge_request, :project, :report_type, :violated_policy, :requires_approval

      def initialize(merge_request, params = {})
        @merge_request = merge_request
        @project = merge_request.project
        @report_type = params['report_type']
        @violated_policy = params['violated_policy']
        @requires_approval = params['requires_approval']
      end

      def execute
        in_lock(exclusive_lock_key, sleep_sec: LOCK_SLEEP_SEC) do
          break ServiceResponse.success if comment.body.blank?

          note = if existing_comment
                   Notes::UpdateService.new(project, bot_user, note_params(comment.body)).execute(existing_comment)
                 else
                   Notes::CreateService.new(project, bot_user, note_params(comment.body)).execute
                 end

          if note.nil? || note.persisted?
            ServiceResponse.success
          else
            ServiceResponse.error(message: note.errors.full_messages)
          end
        end
      rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
        ServiceResponse.error(message: ['Failed to obtain an exclusive lock'])
      end

      private

      def exclusive_lock_key
        "#{self.class.name.underscore}::merge_request_id:#{merge_request.id}"
      end

      def comment
        @comment ||= comment_klass.new(existing_comment, merge_request).tap do |violation_comment|
          if ::Feature.enabled?(:save_policy_violation_data, project)
            initialize_comment(violation_comment)
          else
            initialize_comment_legacy(violation_comment)
          end
        end
      end

      def initialize_comment(violation_comment)
        violated_rules = merge_request.scan_result_policy_violations.filter_map do |violation|
          scan_result_policy_rules[violation.scan_result_policy_id]
        end

        violation_comment.clear_report_types
        violated_rules.each do |rule|
          requires_approval = rule.approvals_required > 0
          violation_comment.add_report_type(rule.report_type, requires_approval)
        end
      end

      def initialize_comment_legacy(violation_comment)
        violation_comment.remove_report_type(report_type)
        violation_comment.add_report_type(report_type, requires_approval) if violated_policy
      end

      def scan_result_policy_rules
        merge_request.approval_rules.applicable_to_branch(merge_request.target_branch)
                     .index_by(&:scan_result_policy_id)
      end
      strong_memoize_attr :scan_result_policy_rules

      def comment_klass
        if ::Feature.enabled?(:save_policy_violation_data, project)
          DetailedPolicyViolationComment
        else
          PolicyViolationComment
        end
      end

      def existing_comment
        @existing_comment ||= merge_request.notes
                                           .authored_by(bot_user)
                                           .note_starting_with(PolicyViolationComment::MESSAGE_HEADER).first
      end

      def bot_user
        @bot_user ||= Users::Internal.security_bot
      end

      def note_params(body)
        {
          note: body,
          noteable: merge_request
        }
      end
    end
  end
end
