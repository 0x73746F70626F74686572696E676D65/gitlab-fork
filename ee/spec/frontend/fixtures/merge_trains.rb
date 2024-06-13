# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "GraphQL Merge Trains", '(JavaScript fixtures)', type: :request, feature_category: :pipeline_composition do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }

  let(:active_query_path) { 'ci/merge_trains/graphql/queries/get_active_merge_trains.query.graphql' }
  let(:completed_query_path) { 'ci/merge_trains/graphql/queries/get_completed_merge_trains.query.graphql' }

  before do
    stub_licensed_features(merge_trains: true)
  end

  context 'with active car' do
    let!(:merge_request) { create_merge_request_on_train }
    let(:train_car) { merge_request.merge_train_car }

    before do
      train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project))
    end

    it "ee/graphql/merge_trains/active_merge_trains.json" do
      query = get_graphql_query_as_string(active_query_path, ee: true)

      post_graphql(query,
        current_user: user,
        variables: { fullPath: project.full_path, targetBranch: 'master' })

      expect_graphql_errors_to_be_empty
    end
  end

  context 'with merged car' do
    let!(:merge_request) { create_merge_request_on_train(source_branch: 'feature-2', status: :merged) }
    let(:train_car) { merge_request.merge_train_car }

    before do
      train_car.update!(pipeline: create(:ci_pipeline, project: train_car.project))
    end

    it "ee/graphql/merge_trains/completed_merge_trains.json" do
      query = get_graphql_query_as_string(completed_query_path, ee: true)

      post_graphql(query,
        current_user: user,
        variables: { fullPath: project.full_path, targetBranch: 'master', status: 'COMPLETED' })

      expect_graphql_errors_to_be_empty
    end
  end

  def create_merge_request_on_train(
    target_project: project, target_branch: 'master', source_project: project,
    source_branch: 'feature-1', status: :idle)
    create(:merge_request,
      :on_train,
      target_branch: target_branch,
      target_project: target_project,
      source_branch: source_branch,
      source_project: source_project,
      status: MergeTrains::Car.state_machines[:status].states[status].value)
  end
end
