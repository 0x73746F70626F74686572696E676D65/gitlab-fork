# frozen_string_literal: true

module Types
  module RemoteDevelopment
    class WorkspaceVariableInputTypeEnum < BaseEnum
      graphql_name 'WorkspaceVariableInputType'
      description 'Enum for the type of the variable to be injected in a workspace.'

      from_rails_enum(
        ::RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL,
        description: "#{%(name).capitalize} type."
      )
    end
  end
end
