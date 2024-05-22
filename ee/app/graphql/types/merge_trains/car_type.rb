# frozen_string_literal: true

module Types
  module MergeTrains
    class CarType < BaseObject
      graphql_name 'MergeTrainCar'

      description 'Represent a car/merge request on a merge train'

      connection_type_class Types::CountableConnectionType
      authorize :read_merge_train

      field :created_at,
        Types::TimeType,
        null: false,
        description: 'Timestamp of when the car was created.'
      field :duration,
        GraphQL::Types::Int,
        null: true,
        description: 'Duration of the car.'
      field :id,
        Types::GlobalIDType[::MergeTrains::Car],
        null: false,
        description: 'Global ID of the car.'
      field :merge_request,
        Types::MergeRequestType,
        null: false,
        description: 'Merge request the car is contains.'
      field :merged_at,
        Types::TimeType,
        null: true,
        description: 'Timestamp of when the car was merged.'
      field :pipeline,
        Types::Ci::PipelineType,
        null: false,
        description: 'Pipeline of the car.'
      field :status,
        CarStatusEnum,
        null: false,
        description: 'Status of the car.'
      # rubocop:disable GraphQL/ExtractType -- The project and branch don't belong in the same type
      field :target_branch,
        Types::BranchType,
        null: false,
        description: "Target branch of the car's merge request."
      field :target_project,
        Types::ProjectType,
        null: false,
        description: "Project the car's MR targets."
      # rubocop:enable GraphQL/ExtractType
      field :updated_at,
        Types::TimeType,
        null: false,
        description: 'Timestamp of when the car was last updated.'
      field :user,
        Types::UserType,
        null: false,
        description: "User that owns the car's merge request."
    end
  end
end
