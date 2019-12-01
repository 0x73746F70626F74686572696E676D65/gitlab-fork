# frozen_string_literal: true

module Projects
  module Licenses
    class CreatePolicyService < ::BaseService
      def execute
        policy = create_policy(find_software_license, params[:classification])
        success(software_license_policy: license_compliance.report_for(policy))
      rescue ActiveRecord::RecordInvalid => exception
        error(exception.record.errors, :unprocessable_entity)
      end

      private

      def license_compliance
        @license_compliance ||= ::SCA::LicenseCompliance.new(project)
      end

      def create_policy(software_license, classification)
        raise error_for(:approval_status, :invalid) unless known?(classification)

        policy = project.software_license_policies.create!(software_license: software_license, approval_status: classification)
        RefreshLicenseComplianceChecksWorker.perform_async(project.id)
        policy
      end

      def find_software_license
        SoftwareLicense.id_in(params[:software_license_id]).or(SoftwareLicense.by_spdx(params[:spdx_identifier])).first
      end

      def known?(classification)
        SoftwareLicensePolicy.approval_statuses.key?(classification)
      end

      def error_for(attribute, error)
        ActiveRecord::RecordInvalid.new(build_error_for(attribute, error))
      end

      def build_error_for(attribute, error)
        SoftwareLicensePolicy.new { |policy| policy.errors.add(attribute, error) }
      end
    end
  end
end
