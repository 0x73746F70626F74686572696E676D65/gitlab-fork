# frozen_string_literal: true

module DefaultBranchProtection
  extend ActiveSupport::Concern

  def normalize_default_branch_params!(form_key)
    target = params[form_key]

    if Gitlab::Utils.to_boolean(target[:default_branch_protected]) == false
      target[:default_branch_protection_defaults] =
        ::Gitlab::Access::BranchProtection.protection_none
    end

    return target unless target.key?(:default_branch_protection_defaults)

    target.delete(:default_branch_protection_level)

    target[:default_branch_protection_defaults][:allowed_to_push].each do |entry|
      entry[:access_level] = entry[:access_level].to_i
    end

    target[:default_branch_protection_defaults][:allowed_to_merge].each do |entry|
      entry[:access_level] = entry[:access_level].to_i
    end

    [:allow_force_push, :code_owner_approval_required, :developer_can_initial_push].each do |key|
      next unless target[:default_branch_protection_defaults].key?(key)

      target[:default_branch_protection_defaults][key] =
        Gitlab::Utils.to_boolean(
          target[:default_branch_protection_defaults][key],
          default: ::Gitlab::Access::BranchProtection.protected_fully[key])
    end
  end
end
