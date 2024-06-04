# frozen_string_literal: true

module SoftwareLicensePolicies
  class CreateService < ::BaseService
    def initialize(project, user, params)
      super(project, user, params.with_indifferent_access)
    end

    def execute
      result = create_for_scan_result_policy
      success(software_license_policy: result)
    rescue ActiveRecord::RecordInvalid => exception
      error(exception.record.errors.full_messages, 400)
    rescue ArgumentError => exception
      log_error(exception.message)
      error(exception.message, 400)
    end

    private

    def create_for_scan_result_policy
      SoftwareLicense.unsafe_create_policy_for!(
        project: project,
        name: params[:name].strip,
        classification: params[:approval_status],
        scan_result_policy_read: params[:scan_result_policy_read]
      )
    end
  end
end
