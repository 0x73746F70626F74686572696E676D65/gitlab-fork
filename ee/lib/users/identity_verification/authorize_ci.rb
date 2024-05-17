# frozen_string_literal: true

module Users
  module IdentityVerification
    Error = Class.new(StandardError)

    class AuthorizeCi
      attr_reader :user, :project

      def initialize(user:, project:)
        @user = user
        @project = project
      end

      def authorize_run_jobs!
        return unless user

        authorize_credit_card!
        authorize_identity_verification!
      end

      private

      def authorize_credit_card!
        return if user.has_required_credit_card_to_run_pipelines?(project)

        ci_access_denied!('Credit card required to be on file in order to run CI jobs')
      end

      def authorize_identity_verification!
        return unless identity_verification_enabled_for_ci?
        return if user.identity_verified?
        return unless project_requires_identity_verification_to_run_pipelines?

        ci_access_denied!('Identity verification is required in order to run CI jobs')
      end

      def identity_verification_enabled_for_ci?
        ::Feature.enabled?(:ci_requires_identity_verification_on_free_plan, project, type: :gitlab_com_derisk)
      end

      def project_requires_identity_verification_to_run_pipelines?
        return false unless project.shared_runners_enabled

        root_namespace = project.root_namespace
        return false if root_namespace.actual_plan.paid_excluding_trials?

        ci_usage = root_namespace.ci_minutes_usage
        return false if ci_usage.quota_enabled? && ci_usage.quota.any_purchased?

        true
      end

      def ci_access_denied!(message)
        log_ci_access_denied(message)

        raise ::Users::IdentityVerification::Error, message
      end

      def log_ci_access_denied(message)
        ::Gitlab::AppLogger.info(
          message: message,
          class: self.class.name,
          project_path: project.full_path,
          user_id: user.id,
          plan: project.root_namespace.actual_plan_name
        )
      end
    end
  end
end
