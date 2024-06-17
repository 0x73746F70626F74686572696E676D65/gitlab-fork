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
      if Feature.enabled?(:custom_software_license, project)
        insert_software_license_policy
      else
        SoftwareLicense.unsafe_create_policy_for!(
          project: project,
          name: params[:name].strip,
          classification: params[:approval_status],
          scan_result_policy_read: params[:scan_result_policy_read]
        )
      end
    end

    def insert_software_license_policy
      software_license = SoftwareLicense.find_by_name(params[:name])

      if software_license
        create_software_license_policies_with_software_license(software_license)
      else
        create_software_license_policies_with_custom_software_license(custom_software_license)
      end
    end

    def create_software_license_policies_with_software_license(software_license)
      project.software_license_policies.create!(
        classification: params[:approval_status],
        software_license: software_license,
        scan_result_policy_read: params[:scan_result_policy_read]
      )
    end

    def create_software_license_policies_with_custom_software_license(custom_software_license)
      project.software_license_policies.create!(
        classification: params[:approval_status],
        custom_software_license: custom_software_license,
        scan_result_policy_read: params[:scan_result_policy_read]
      )
    end

    def custom_software_license
      response = Security::CustomSoftwareLicenses::FindOrCreateService.new(project: project,
        params: params).execute

      response.payload[:custom_software_license]
    end
  end
end
