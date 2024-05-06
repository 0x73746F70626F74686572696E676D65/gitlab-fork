# frozen_string_literal: true

module Resolvers
  module SecurityOrchestration
    class ScanResultPolicyResolver < BaseResolver
      include ResolvesOrchestrationPolicy

      type Types::SecurityOrchestration::ScanResultPolicyType, null: true

      argument :relationship, ::Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum,
        description: 'Filter policies by the given policy relationship.',
        required: false,
        default_value: :direct

      def resolve(**args)
        policies = Security::ScanResultPoliciesFinder.new(context[:current_user], object,
          args.merge(include_invalid: true)).execute
        construct_scan_result_policies(policies)
      end
    end
  end
end
