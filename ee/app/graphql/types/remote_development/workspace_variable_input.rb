# frozen_string_literal: true

module Types
  module RemoteDevelopment
    class WorkspaceVariableInput < BaseInputObject
      graphql_name 'WorkspaceVariableInput'
      description 'Attributes for defining a variable to be injected in a workspace.'

      # do not allow empty values. also validate that the key contains only alphanumeric characters, -, _ or .
      # https://kubernetes.io/docs/concepts/configuration/secret/#restriction-names-data
      argument :key, GraphQL::Types::String,
        description: 'Key of the variable.',
        validates: {
          allow_blank: false,
          format: { with: /\A[a-zA-Z0-9\-_.]+\z/, message: 'must contain only alphanumeric characters, -, _ or .' }
        }
      argument :type, Types::RemoteDevelopment::WorkspaceVariableInputTypeEnum,
        description: 'Type of the variable to be injected in a workspace.'
      argument :value, GraphQL::Types::String, description: 'Value of the variable.'
    end
  end
end
