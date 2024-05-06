# frozen_string_literal: true

module Resolvers
  module SecurityOrchestration
    class ScanExecutionPolicyResolver < BaseResolver
      include ResolvesOrchestrationPolicy

      type Types::SecurityOrchestration::ScanExecutionPolicyType, null: true

      argument :action_scan_types, [::Types::Security::ReportTypeEnum],
        description: "Filters policies by the action scan type. "\
                   "Only these scan types are supported: #{::Security::ScanExecutionPolicy::SCAN_TYPES.map { |type| "`#{type}`" }.join(', ')}.",
        required: false

      argument :relationship, ::Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum,
        description: 'Filter policies by the given policy relationship.',
        required: false,
        default_value: :direct

      def resolve(**args)
        policies = Security::ScanExecutionPoliciesFinder.new(context[:current_user], project, args).execute
        construct_scan_execution_policies(policies)
      end
    end
  end
end
