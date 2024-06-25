# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class AddApproversToRulesWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      feature_category :security_policy_management
      idempotent!

      concurrency_limit -> { 200 }

      def self.dispatch?(event)
        return unless event.data[:project_id]

        project = Project.find_by_id(event.data[:project_id])
        return unless project

        project.licensed_feature_available?(:security_orchestration_policies) &&
          project.scan_result_policy_reads.any?

        # TODO: Add check if we have any rules in defined policies that requires this worker to perform
        # TODO: This will be possible after delivery of https://gitlab.com/groups/gitlab-org/-/epics/9971
      end

      def handle_event(event)
        user_ids = event.data[:user_ids]
        return if user_ids.blank?

        project_id = event.data[:project_id]
        project = Project.find_by_id(project_id)

        unless project
          logger.info(structured_payload(message: 'Project not found.', project_id: project_id))
          return
        end

        return unless project.licensed_feature_available?(:security_orchestration_policies)

        Security::ScanResultPolicies::AddApproversToRulesService.new(project: project).execute(user_ids)
      end
    end
  end
end
