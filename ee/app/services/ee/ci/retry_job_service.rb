# frozen_string_literal: true

module EE
  module Ci
    module RetryJobService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :check_access!
      def check_access!(build)
        super

        begin
          ::Users::IdentityVerification::AuthorizeCi.new(user: current_user, project: project).authorize_run_jobs!
        rescue ::Users::IdentityVerification::Error => e
          raise ::Gitlab::Access::AccessDeniedError, e
        end
      end

      override :check_assignable_runners!
      def check_assignable_runners!(build)
        build_matcher = build.build_matcher
        build.drop!(:ci_quota_exceeded) unless runner_minutes.available?(build_matcher)
      end

      def runner_minutes
        ::Gitlab::Ci::RunnersAvailabilityBuilder.instance_for(project).minutes_checker
      end
    end
  end
end
