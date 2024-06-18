# frozen_string_literal: true

module Resolvers
  module ProductAnalytics
    class VisualizationResolver < BaseResolver
      type ::Types::ProductAnalytics::VisualizationType, null: true

      def resolve
        object.visualization
      end
    end
  end
end
