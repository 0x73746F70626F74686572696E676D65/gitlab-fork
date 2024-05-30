# frozen_string_literal: true

module Security
  module PolicyRule
    extend ActiveSupport::Concern

    def self.for_policy_type(policy_type)
      case policy_type
      when :approval_policy then Security::ApprovalPolicyRule
      when :scan_execution_policy then Security::ScanExecutionPolicyRule
      else raise ArgumentError, "unrecognized policy_type"
      end
    end

    included do
      self.inheritance_column = :_type_disabled
    end

    class_methods do
      def attributes_from_rule_hash(rule_hash, policy_configuration)
        {
          type: rule_hash[:type],
          content: rule_hash.without(:type),
          security_policy_management_project_id: policy_configuration.security_policy_management_project_id
        }
      end
    end

    def typed_content
      content.deep_stringify_keys.merge("type" => type)
    end
  end
end
