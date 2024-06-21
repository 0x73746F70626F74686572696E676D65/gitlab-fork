# frozen_string_literal: true

module Types
  module Analytics
    # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
    class AiMetrics < BaseObject
      field :code_contributors_count, GraphQL::Types::Int,
        description: 'Number of code contributors.',
        null: true
      field :code_suggestions_accepted_count, GraphQL::Types::Int,
        description: 'Total count of code suggestions accepted by code contributors.',
        null: true
      field :code_suggestions_contributors_count, GraphQL::Types::Int,
        description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
        null: true
      field :code_suggestions_shown_count, GraphQL::Types::Int,
        description: 'Total count of code suggestions shown to code contributors.',
        null: true
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
