# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciRunnerUsageByProject', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers

  let_it_be(:projects) { create_list(:project, 7) }
  let_it_be(:project) { projects.first }
  let_it_be(:instance_runner) { create(:ci_runner, :instance, :with_runner_manager) }
  let_it_be(:project_runner) { create(:ci_runner, :project, :with_runner_manager) }

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:starting_date) { Date.new(2023) }

  let(:runner_type) { nil }
  let(:from_date) { starting_date }
  let(:to_date) { starting_date + 1.day }
  let(:projects_limit) { nil }

  let(:params) do
    { runner_type: runner_type, from_date: from_date, to_date: to_date, projects_limit: projects_limit }.compact
  end

  let(:query_path) do
    [
      [:runner_usage_by_project, params]
    ]
  end

  let(:query_node) do
    <<~QUERY
      project {
        id
        name
        fullPath
      }
      ciMinutesUsed
      ciBuildCount
    QUERY
  end

  let(:current_user) { admin }

  let(:query) do
    graphql_query_for('runnerUsageByProject', params, query_node)
  end

  let(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  let(:licensed_feature_available) { true }

  subject(:runner_usage_by_project) do
    execute_query
    graphql_data_at(:runner_usage_by_project)
  end

  before do
    stub_licensed_features(runner_performance_insights: licensed_feature_available)
  end

  shared_examples "returns unauthorized or unavailable error" do
    it 'returns error' do
      execute_query

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist " \
                                       "or you don't have permission to perform this action")
    end
  end

  context "when ClickHouse database is not configured" do
    before do
      allow(ClickHouse::Client).to receive(:database_configured?).and_return(false)
    end

    include_examples "returns unauthorized or unavailable error"
  end

  context "when runner_performance_insights feature is disabled" do
    let(:licensed_feature_available) { false }

    include_examples "returns unauthorized or unavailable error"
  end

  context "when user is nil" do
    let(:current_user) { nil }

    include_examples "returns unauthorized or unavailable error"
  end

  context "when user is not admin" do
    let(:current_user) { create(:user) }

    include_examples "returns unauthorized or unavailable error"
  end

  context "when service returns an error" do
    before do
      allow_next_instance_of(::Ci::Runners::GetUsageByProjectService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error 123'))
      end
    end

    it 'returns this error' do
      execute_query

      expect_graphql_errors_to_include("error 123")
    end
  end

  it 'returns empty runner_usage_by_project with no data' do
    expect(runner_usage_by_project).to eq([])
  end

  shared_examples 'returns top N projects' do |n|
    let(:top_projects) { projects.first(n) }
    let(:other_projects) { projects - top_projects }

    it "returns #{n} projects consuming most of the runner minutes and one line for the 'rest'" do
      builds = top_projects.each_with_index.flat_map do |project, index|
        Array.new(index + 1) do
          stubbed_build(starting_date, 20.minutes, project: project)
        end
      end

      builds += other_projects.flat_map do |project|
        Array.new(3) do
          stubbed_build(starting_date, 2.minutes, project: project)
        end
      end

      insert_ci_builds_to_click_house(builds)

      expected_result = top_projects.each_with_index.flat_map do |project, index|
        {
          "project" => a_graphql_entity_for(project, :name, :full_path),
          "ciMinutesUsed" => (20 * (index + 1)).to_s,
          "ciBuildCount" => (index + 1).to_s
        }
      end.reverse + [{
        "project" => nil,
        "ciMinutesUsed" => (other_projects.count * 3 * 2).to_s,
        "ciBuildCount" => (other_projects.count * 3).to_s
      }]

      expect(runner_usage_by_project).to match(expected_result)
    end
  end

  include_examples 'returns top N projects', 5

  context 'when projects_limit = 2' do
    let(:projects_limit) { 2 }

    include_examples 'returns top N projects', 2
  end

  context 'when projects_limit > MAX_PROJECTS_LIMIT' do
    let(:projects_limit) { 5 }

    before do
      stub_const('Resolvers::Ci::RunnerUsageByProjectResolver::MAX_PROJECTS_LIMIT', 3)
    end

    include_examples 'returns top N projects', 3
  end

  it 'only counts builds from from_date to to_date' do
    builds = [from_date - 1.minute,
      from_date,
      to_date + 1.day - 1.minute,
      to_date + 1.day].each_with_index.map do |finished_at, index|
      stubbed_build(finished_at, (index + 1).minutes)
    end
    insert_ci_builds_to_click_house(builds)

    expect(runner_usage_by_project).to contain_exactly({
      'project' => a_graphql_entity_for(project, :name, :full_path),
      'ciMinutesUsed' => '5',
      'ciBuildCount' => '2'
    })
  end

  context 'when from_date and to_date are not specified' do
    let(:from_date) { nil }
    let(:to_date) { nil }

    around do |example|
      travel_to(Date.new(2024, 2, 1)) do
        example.run
      end
    end

    it 'defaults time frame to the last calendar month' do
      from_date_default = Date.new(2024, 1, 1)
      to_date_default = Date.new(2024, 1, 31)

      builds = [from_date_default - 1.minute,
        from_date_default,
        to_date_default + 1.day - 1.minute,
        to_date_default + 1.day].each_with_index.map do |finished_at, index|
        stubbed_build(finished_at, (index + 1).minutes)
      end
      insert_ci_builds_to_click_house(builds)

      expect(runner_usage_by_project).to contain_exactly({
        'project' => a_graphql_entity_for(project, :name, :full_path),
        'ciMinutesUsed' => '5',
        'ciBuildCount' => '2'
      })
    end
  end

  context 'when runner_type is specified' do
    let(:runner_type) { :PROJECT_TYPE }

    it 'filters data by runner type' do
      builds = [
        stubbed_build(starting_date, 21.minutes),
        stubbed_build(starting_date, 33.minutes, runner: project_runner)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(runner_usage_by_project).to contain_exactly({
        'project' => a_graphql_entity_for(project, :name, :full_path),
        'ciMinutesUsed' => '33',
        'ciBuildCount' => '1'
      })
    end
  end

  context 'when requesting more than 1 year' do
    let(:to_date) { from_date + 13.months }

    it 'returns error' do
      execute_query

      expect_graphql_errors_to_include("'to_date' must be greater than 'from_date' and be within 1 year")
    end
  end

  context 'when to_date is before from_date' do
    let(:to_date) { from_date - 1.day }

    it 'returns error' do
      execute_query

      expect_graphql_errors_to_include("'to_date' must be greater than 'from_date' and be within 1 year")
    end
  end

  def stubbed_build(finished_at, duration, project: projects.first, runner: instance_runner)
    created_at = finished_at - duration

    build_stubbed(:ci_build,
      :success,
      project: project,
      created_at: created_at,
      queued_at: created_at,
      started_at: created_at,
      finished_at: finished_at,
      runner: runner,
      runner_manager: runner.runner_managers.first)
  end
end
