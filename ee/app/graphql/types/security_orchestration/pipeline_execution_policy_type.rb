# frozen_string_literal: true

module Types
  module SecurityOrchestration
    # rubocop: disable Graphql/AuthorizeTypes -- authorization
    # this represents a hash, from the orchestration policy configuration
    # the authorization happens for that configuration
    class PipelineExecutionPolicyType < BaseObject
      graphql_name 'PipelineExecutionPolicy'
      description 'Represents the pipeline execution policy'

      implements OrchestrationPolicyType

      field :source, Types::SecurityOrchestration::SecurityPolicySourceType,
        null: false,
        description: 'Source of the policy. Its fields depend on the source type.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
