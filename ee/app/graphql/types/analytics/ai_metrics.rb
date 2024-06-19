# frozen_string_literal: true

module Types
  module Analytics
    # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
    class AiMetrics < BaseObject
      field :code_contributors_count, GraphQL::Types::Int,
        description: 'Number of code contributors.',
        null: false
      field :code_suggestions_contributors_count, GraphQL::Types::Int,
        description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
        null: false
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
