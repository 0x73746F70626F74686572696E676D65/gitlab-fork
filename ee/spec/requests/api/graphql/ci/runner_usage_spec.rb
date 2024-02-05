# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciRunnerUsageByProject', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:instance_runners) { create_list(:ci_runner, 7, :instance, :with_runner_manager) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:starting_date) { Date.new(2023) }

  let(:runner_type) { nil }
  let(:from_date) { starting_date }
  let(:to_date) { starting_date + 1.day }
  let(:runners_limit) { nil }

  let(:params) do
    { runner_type: runner_type, from_date: from_date, to_date: to_date, runners_limit: runners_limit }.compact
  end

  let(:query_path) do
    [
      [:runner_usage, params]
    ]
  end

  let(:query_node) do
    <<~QUERY
      runner {
        id
        description
      }
      ciMinutesUsed
      ciBuildCount
    QUERY
  end

  let(:current_user) { admin }

  let(:query) do
    graphql_query_for('runnerUsage', params, query_node)
  end

  let(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  let(:licensed_feature_available) { true }

  subject(:runner_usage) do
    execute_query
    graphql_data_at(:runner_usage)
  end

  before do
    stub_licensed_features(runner_performance_insights: licensed_feature_available)
  end

  shared_examples "returns unauthorized error" do
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

    include_examples "returns unauthorized error"
  end

  context "when runner_performance_insights feature is disabled" do
    let(:licensed_feature_available) { false }

    include_examples "returns unauthorized error"
  end

  context "when user is nil" do
    let(:current_user) { nil }

    include_examples "returns unauthorized error"
  end

  context "when user is not admin" do
    let(:current_user) { create(:user) }

    include_examples "returns unauthorized error"
  end

  context "when service returns an error" do
    before do
      allow_next_instance_of(::Ci::Runners::GetUsageService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error 123'))
      end
    end

    it 'returns this error' do
      execute_query

      expect_graphql_errors_to_include("error 123")
    end
  end

  it 'returns empty runner_usage with no data' do
    expect(runner_usage).to eq([])
  end

  shared_examples 'returns top N runners' do |n|
    let(:top_runners) { instance_runners.first(n) }
    let(:other_runners) { instance_runners - top_runners }

    it "returns #{n} runners executed most of the ci minutes and one line for the 'rest'" do
      builds = top_runners.each_with_index.flat_map do |runner, index|
        Array.new(index + 1) do
          stubbed_build(starting_date, 20.minutes, runner: runner)
        end
      end

      builds += other_runners.flat_map do |runner|
        Array.new(3) do
          stubbed_build(starting_date, 2.minutes, runner: runner)
        end
      end

      insert_ci_builds_to_click_house(builds)

      expected_result = top_runners.each_with_index.flat_map do |runner, index|
        {
          "runner" => a_graphql_entity_for(runner, :description),
          "ciMinutesUsed" => 20 * (index + 1),
          "ciBuildCount" => index + 1
        }
      end.reverse + [{
        "runner" => nil,
        "ciMinutesUsed" => other_runners.count * 3 * 2,
        "ciBuildCount" => other_runners.count * 3
      }]

      expect(runner_usage).to match(expected_result)
    end
  end

  include_examples 'returns top N runners', 5

  context 'when runners_limit = 2' do
    let(:runners_limit) { 2 }

    include_examples 'returns top N runners', 2
  end

  context 'when runners_limit > MAX_RUNNERS_LIMIT' do
    let(:runners_limit) { 5 }

    before do
      stub_const('Resolvers::Ci::RunnerUsageResolver::MAX_RUNNERS_LIMIT', 3)
    end

    include_examples 'returns top N runners', 3
  end

  it 'only counts builds from from_date to to_date' do
    builds = [from_date - 1.minute,
      from_date,
      to_date + 1.day - 1.minute,
      to_date + 1.day].each_with_index.map do |finished_at, index|
      stubbed_build(finished_at, (index + 1).minutes)
    end
    insert_ci_builds_to_click_house(builds)

    expect(runner_usage).to match([
      {
        "runner" => a_graphql_entity_for(instance_runners.first, :description),
        "ciMinutesUsed" => 5,
        "ciBuildCount" => 2
      }
    ])
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

      expect(runner_usage).to match([
        {
          "runner" => a_graphql_entity_for(instance_runners.first, :description),
          "ciMinutesUsed" => 5,
          "ciBuildCount" => 2
        }
      ])
    end
  end

  context 'when runner_type is specified' do
    let(:runner_type) { :GROUP_TYPE }

    it 'filters data by runner type' do
      builds = [
        stubbed_build(starting_date, 21.minutes),
        stubbed_build(starting_date, 33.minutes, runner: group_runner)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(runner_usage).to match([
        {
          "runner" => a_graphql_entity_for(group_runner, :description),
          "ciMinutesUsed" => 33,
          "ciBuildCount" => 1
        }
      ])
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

  def stubbed_build(finished_at, duration, runner: instance_runners.first)
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
