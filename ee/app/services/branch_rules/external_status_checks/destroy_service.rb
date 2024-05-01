# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class DestroyService < BaseService
      def execute(skip_authorization: false)
        super
      rescue Gitlab::Access::AccessDeniedError
        ServiceResponse.error(
          message: 'Failed to destroy external status check',
          payload: { errors: ['Not allowed'] },
          reason: :access_denied
        )
      end

      private

      def authorized?
        can?(current_user, :update_branch_rule, branch_rule)
      end

      def execute_on_branch_rule
        ::ExternalStatusChecks::DestroyService.new(
          container: project,
          current_user: current_user
        ).execute(external_status_check, skip_authorization: true)
      rescue ActiveRecord::RecordNotFound => exception
        ServiceResponse.error(
          message: exception.message,
          payload: { errors: ['Not found'] },
          reason: :not_found
        )
      end

      def execute_on_all_branches_rule
        ServiceResponse.error(message: 'All branch rules cannot configure external status checks')
      end

      def execute_on_all_protected_branches_rule
        ServiceResponse.error(message: 'All protected branch rules cannot configure external status checks')
      end

      def external_status_check
        @external_status_check ||= project.external_status_checks.find(params[:id])
      end

      def permitted_params
        [:id]
      end
    end
  end
end
