# frozen_string_literal: true

module ExternalStatusChecks
  class UpdateService < BaseService
    ERROR_MESSAGE = 'Failed to update external status check'

    def execute
      return unauthorized_error_response unless current_user.can?(:admin_project, container)

      if with_audit_logged(external_status_check, 'update_status_check') do
        external_status_check.update(resource_params)
      end
        log_audit_event
        ServiceResponse.success(payload: { external_status_check: external_status_check })
      else
        ServiceResponse.error(message: ERROR_MESSAGE,
                              payload: { errors: external_status_check.errors.full_messages },
                              http_status: :unprocessable_entity)
      end
    end

    private

    def resource_params
      params.slice(:name, :external_url, :protected_branch_ids)
    end

    def external_status_check
      @external_status_check ||= container.external_status_checks.find(params[:check_id])
    end

    def unauthorized_error_response
      ServiceResponse.error(
        message: ERROR_MESSAGE,
        payload: { errors: ['Not allowed'] },
        http_status: :unauthorized
      )
    end

    def log_audit_event
      Audit::ExternalStatusCheckChangesAuditor.new(current_user, external_status_check).execute
    end
  end
end
