# frozen_string_literal: true

module Types
  module MergeTrains
    class TrainType < BaseObject
      graphql_name 'MergeTrain'
      description 'Represents a set of cars/merge_requests queued for merging'

      connection_type_class Types::CountableConnectionType
      authorize :read_merge_train

      alias_method :merge_train, :object

      field :cars,
        Types::MergeTrains::CarType.connection_type,
        null: false,
        description: "Cars queued in the train.",
        alpha: { milestone: '17.1' } do
        argument :activity_status,
          ::Types::MergeTrains::TrainStatusEnum,
          required: true,
          default_value: "active",
          description: 'Filter cars by their high-level status. Defaults to ACTIVE.'
      end

      field :target_branch,
        GraphQL::Types::String,
        null: false,
        description: "Target branch of the car's merge request."

      def cars(activity_status:)
        case activity_status
        when 'active'
          merge_train.all_cars
        when 'completed'
          merge_train.completed_cars
        end
      end
    end
  end
end
