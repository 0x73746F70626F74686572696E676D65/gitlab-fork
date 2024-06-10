# frozen_string_literal: true

module RemoteDevelopment
  # This module contains all messages for the EE part of the Remote Development domain, both errors and domain events.
  # Note that we intentionally have not DRY'd up the declaration of the subclasses with loops and
  # metaprogramming, because we want the types to be easily indexable and navigable within IDEs.
  module Messages
    #---------------------------------------------------------------
    # Errors - message name should describe the reason for the error
    #---------------------------------------------------------------

    # License error
    LicenseCheckFailed = Class.new(Message)

    # Auth errors
    Unauthorized = Class.new(Message)

    # AgentConfig errors
    AgentConfigUpdateFailed = Class.new(Message)

    # Workspace create errors
    WorkspaceCreateParamsValidationFailed = Class.new(Message)
    WorkspaceCreateDevfileLoadFailed = Class.new(Message)
    WorkspaceCreateDevfileYamlParseFailed = Class.new(Message)
    WorkspaceCreatePreFlattenDevfileValidationFailed = Class.new(Message)
    WorkspaceCreateDevfileFlattenFailed = Class.new(Message)
    WorkspaceCreatePostFlattenDevfileValidationFailed = Class.new(Message)
    PersonalAccessTokenModelCreateFailed = Class.new(Message)
    WorkspaceModelCreateFailed = Class.new(Message)
    WorkspaceVariablesModelCreateFailed = Class.new(Message)
    WorkspaceCreateFailed = Class.new(Message)

    # Workspace update errors
    WorkspaceUpdateFailed = Class.new(Message)

    # Workspace reconcile errors
    WorkspaceReconcileParamsValidationFailed = Class.new(Message)

    # Namespace Cluster Agent Mapping create errors
    NamespaceClusterAgentMappingAlreadyExists = Class.new(Message)
    NamespaceClusterAgentMappingCreateFailed = Class.new(Message)
    NamespaceClusterAgentMappingCreateValidationFailed = Class.new(Message)

    # Namespace Cluster Agent Mapping delete errors
    NamespaceClusterAgentMappingNotFound = Class.new(Message)

    #---------------------------------------------------------
    # Domain Events - message name should describe the outcome
    #---------------------------------------------------------

    # AgentConfig domain events
    AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound = Class.new(Message)
    AgentConfigUpdateSuccessful = Class.new(Message)

    # Workspace domain events
    WorkspaceCreateSuccessful = Class.new(Message)
    WorkspaceUpdateSuccessful = Class.new(Message)
    WorkspaceReconcileSuccessful = Class.new(Message)

    # Namespace Cluster Agent Mapping domain events
    NamespaceClusterAgentMappingCreateSuccessful = Class.new(Message)
    NamespaceClusterAgentMappingDeleteSuccessful = Class.new(Message)
  end
end
