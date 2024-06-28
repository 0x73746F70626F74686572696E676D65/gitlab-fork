# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.mergeTrains.cars', feature_category: :merge_trains do
  include GraphqlHelpers

  let_it_be(:target_project) { create(:project, :repository) }
  let(:car_fields) do
    <<~QUERY
      nodes {
        status
        mergeRequest {
          title
        }
        pipeline {
          status
        }
      }
    QUERY
  end

  let(:train_fields) do
    <<~QUERY
      nodes {
        targetBranch
        #{car_query}
      }
    QUERY
  end

  let(:car_query) do
    query_graphql_field(
      :cars,
      car_params,
      car_fields
    )
  end

  let(:train_query) do
    query_graphql_field(
      :merge_trains,
      params,
      train_fields
    )
  end

  let_it_be(:reporter) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let(:query) { graphql_query_for(:project, { full_path: target_project.full_path }, train_query) }
  let(:user) { reporter }
  let(:params) { { status: ::MergeTrains::Train::STATUSES[:active].upcase.to_sym } }
  let(:car_params) { {} }
  let(:post_query) { post_graphql(query, current_user: user) }
  let(:data) { graphql_data }

  subject(:result) { graphql_data_at(:project, :merge_trains, :nodes, :target_branch) }

  before do
    stub_licensed_features(merge_trains: true)
  end

  before_all do
    target_project.ci_cd_settings.update!(merge_trains_enabled: true)
    target_project.add_reporter(reporter)
    target_project.add_guest(guest)
    target_project.add_maintainer(maintainer)
    create_merge_request_on_train(project: target_project, author: maintainer)
    create_merge_request_on_train(project: target_project, source_branch: 'branch-1', author: maintainer)
    create_merge_request_on_train(project: target_project, source_branch: 'branch-2', status: :merged,
      author: maintainer)
    create_merge_request_on_train(project: target_project, target_branch: 'feature-1', author: maintainer)
    create_merge_request_on_train(project: target_project, target_branch: 'feature-2', status: :merged,
      author: maintainer)
    create(:merge_train_car, target_project: create(:project), target_branch: 'master')
  end

  shared_examples 'fetches the requested trains' do
    before do
      post_query
    end

    it 'returns relevant merge trains' do
      expect(result).to contain_exactly(*expected_branches)
    end

    it 'does not have N+1 problem', :use_sql_query_cache do
      # warm up the query to avoid flakiness
      run_query

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { run_query }

      create_merge_request_on_train(project: target_project, source_branch: 'branch-7', author: maintainer)
      create_merge_request_on_train(project: target_project, source_branch: 'branch-6', target_branch: 'feature-1',
        author: maintainer)

      expect { run_query }.to issue_same_number_of_queries_as(control)
    end
  end

  context 'when the user does not have the permissions' do
    let(:user) { guest }

    it 'returns a resource not available error' do
      post_query
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  context 'when the project does not have the required license' do
    before do
      stub_licensed_features(merge_trains: false)
    end

    it 'returns a resource not available error' do
      post_query
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  context 'when the user has the right permissions' do
    context 'when the feature is disabled' do
      before do
        stub_feature_flags(merge_trains_viz: false)
      end

      it 'returns a resource not available error' do
        post_query
        expect_graphql_errors_to_include(
          "The resource that you are attempting to access does not exist " \
            "or you don't have permission to perform this action"
        )
      end
    end

    context 'when only the project is provided' do
      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[master feature-1] }
      end
    end

    context 'when target_branches are provided' do
      let(:params) do
        {
          target_branches: %w[feature-1 feature-2],
          status: ::MergeTrains::Train::STATUSES[:active].upcase.to_sym
        }
      end

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-1] }
      end

      context 'when status is provided' do
        before do
          params[:status] = ::MergeTrains::Train::STATUSES[:completed].upcase.to_sym
        end

        it_behaves_like 'fetches the requested trains' do
          let(:expected_branches) { %w[feature-2] }
        end
      end
    end

    context 'when train status is provided' do
      let(:params) { { status: ::MergeTrains::Train::STATUSES[:completed].upcase.to_sym } }

      it_behaves_like 'fetches the requested trains' do
        let(:expected_branches) { %w[feature-2] }
      end
    end

    context 'when car params are provided' do
      let(:result) { graphql_data_at(:project, :merge_trains, :nodes, :cars, :nodes) }

      before do
        create_merge_request_on_train(project: target_project, source_branch: 'branch-4', author: maintainer)
        create_merge_request_on_train(project: target_project, source_branch: 'branch-5', status: :merged,
          author: maintainer)
        create_merge_request_on_train(project: target_project, source_branch: 'branch-6', status: :merged,
          author: maintainer)
      end

      it 'fetches the active cars for each train' do
        post_query
        result.each { |car| expect(car['status']).to eq('IDLE') }
      end

      context 'when the status is COMPLETED' do
        let(:car_params) { { activity_status: :COMPLETED } }

        it 'fetches the first completed cars for each train' do
          post_query
          result.each { |car| expect(car['status']).to eq('MERGED') }
        end
      end
    end
  end

  private

  def create_merge_request_on_train(project:, author:, target_branch: 'master', source_branch: 'feature', status: :idle)
    merge_request = create(:merge_request, :on_train,
      source_project: project,
      target_project: project,
      target_branch: target_branch,
      source_branch: source_branch,
      author: author,
      status: MergeTrains::Car.state_machines[:status].states[status].value)

    merge_request.merge_train_car.update!(pipeline: create(:ci_pipeline, user: author, project: project))
  end

  def run_query
    post_graphql(query, current_user: user)
  end
end
