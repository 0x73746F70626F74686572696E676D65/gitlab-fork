# frozen_string_literal: true

module SoftwareLicensePolicies
  class BulkCreateScanResultPolicyService < ::BaseService
    include ::Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 250

    def initialize(project, params)
      super(project, nil, params)
    end

    def execute
      existing_licenses = SoftwareLicense.by_name(license_names).limit(license_names.size).pluck(:name, :id).to_h # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- Array#pluck
      missing_licenses_names = license_names - existing_licenses.keys

      created_custom_licenses = create_unknown_custom_licenses(missing_licenses_names)

      software_license_policies = create_software_license_policies(created_custom_licenses, existing_licenses)

      success(software_license_policy: software_license_policies)
    end

    private

    def license_names
      params.map { |license| license.with_indifferent_access[:name].strip }.uniq
    end
    strong_memoize_attr :license_names

    def create_unknown_custom_licenses(missing_licenses_names)
      created_custom_licenses = []
      missing_licenses_names.each_slice(BATCH_SIZE) do |names|
        created_custom_licenses << Security::CustomSoftwareLicense.upsert_all(names.map do |name|
          { name: name, project_id: project.id }
        end, unique_by: [:project_id, :name], returning: %w[name id])
      end

      created_custom_licenses.flatten.pluck('name', 'id').to_h # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- Array#pluck
    end

    def create_software_license_policies(created_custom_licenses, existing_licenses)
      software_license_policies =
        software_license_policies_to_insert(software_licenses: existing_licenses) +
        software_license_policies_to_insert(custom_software_licenses: created_custom_licenses)

      software_license_policies.each_slice(BATCH_SIZE) do |batch|
        SoftwareLicensePolicy.insert_all(batch)
      end
    end

    def software_license_policies_to_insert(software_licenses: nil, custom_software_licenses: nil)
      attributes_to_reject = %w[id created_at updated_at approval_policy_rule_id]

      params.filter_map do |policy_params|
        license_name = policy_params[:name].strip

        record = SoftwareLicensePolicy.new(
          project_id: project.id,
          # software_license_id will be nil if software_licenses is nil
          software_license_id: software_licenses && software_licenses[license_name],
          # custom_software_license_id will be nil if custom_software_licenses is nil
          custom_software_license_id: custom_software_licenses && custom_software_licenses[license_name],
          classification: policy_params[:approval_status],
          scan_result_policy_id: policy_params[:scan_result_policy_read]&.id
        )

        next if record.scan_result_policy_id.nil? || record.invalid?

        # Ensure the same keys for bulk insert
        record.attributes.reject! { |k| attributes_to_reject.include?(k) }
      end
    end
  end
end
