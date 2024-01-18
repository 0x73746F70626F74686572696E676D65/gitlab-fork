# frozen_string_literal: true

# noinspection RubyClassModuleNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
module EE
  module Types
    module CurrentUserType
      extend ActiveSupport::Concern

      prepended do
        field :workspaces,
          description: 'Workspaces owned by the current user.',
          resolver: ::Resolvers::RemoteDevelopment::WorkspacesForCurrentUserResolver

        field :duo_chat_available, ::GraphQL::Types::Boolean,
          resolver: ::Resolvers::Ai::UserChatAccessResolver,
          alpha: { milestone: '16.8' },
          description: 'User access to AI chat feature.'

        field :duo_code_suggestions_available, ::GraphQL::Types::Boolean,
          resolver: ::Resolvers::Ai::CodeSuggestionsAccessResolver,
          alpha: { milestone: '16.8' },
          description: 'User access to code suggestions feature.'
      end
    end
  end
end
