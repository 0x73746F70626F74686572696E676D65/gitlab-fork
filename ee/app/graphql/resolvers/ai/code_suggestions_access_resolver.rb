# frozen_string_literal: true

module Resolvers
  module Ai
    class CodeSuggestionsAccessResolver < BaseResolver
      type ::GraphQL::Types::Boolean, null: false

      def resolve
        return false unless current_user

        Feature.enabled?(:ai_duo_code_suggestions_switch, type: :ops) &&
          CloudConnector::AvailableServices.find_by_name(:code_suggestions).allowed_for?(current_user)
      end
    end
  end
end
