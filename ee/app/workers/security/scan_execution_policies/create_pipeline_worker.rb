# frozen_string_literal: true

module Security
  module ScanExecutionPolicies
    class CreatePipelineWorker # rubocop:disable Scalability/IdempotentWorker -- The worker should not run multiple times to avoid creating multiple pipelines
      include ApplicationWorker

      feature_category :security_policy_management
      deduplicate :until_executing
      urgency :throttled
      data_consistency :delayed

      concurrency_limit -> { Gitlab::CurrentSettings.security_policy_scheduled_scans_max_concurrency }

      def perform(project_id, current_user_id, schedule_id, branch)
        project = Project.find_by_id(project_id)
        return unless project

        current_user = User.find_by_id(current_user_id)
        return unless current_user

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(schedule_id)
        return unless schedule

        actions = actions_for(schedule)

        service_result = ::Security::SecurityOrchestrationPolicies::CreatePipelineService
          .new(project: project, current_user: current_user, params: { actions: actions, branch: branch })
          .execute

        return unless service_result[:status] == :error

        log_error(current_user, schedule, service_result[:message])
      end

      private

      def actions_for(schedule)
        policy = schedule.policy
        return [] if policy.blank?

        policy[:actions]
      end

      def log_error(current_user, schedule, message)
        ::Gitlab::AppJsonLogger.warn(
          build_structured_payload(
            security_orchestration_policy_configuration_id: schedule&.security_orchestration_policy_configuration&.id,
            user_id: current_user.id,
            message: message
          )
        )
      end
    end
  end
end
