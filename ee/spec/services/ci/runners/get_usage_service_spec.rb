# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::GetUsageService, :click_house, :enable_admin_mode, feature_category: :fleet_visibility do
  let_it_be(:project) { create(:project) }
  let_it_be(:instance_runners) { create_list(:ci_runner, 3, :instance, :with_runner_manager) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }

  let_it_be(:builds_finished_at) { Date.new(2023, 12, 1) }
  let_it_be(:group_runner_builds) { Array.new(5) { create_build(group_runner, builds_finished_at, 100.minutes) } }
  let_it_be(:instance_runner_builds) do
    instance_runners.each_with_index.flat_map do |runner, index|
      Array.new(index + 1) do
        create_build(runner, builds_finished_at, 10.minutes)
      end
    end
  end

  let_it_be(:builds) { instance_runner_builds + group_runner_builds }

  let_it_be(:user) { create(:admin) }
  let(:runner_type) { nil }
  let(:from_date) { Date.new(2023, 12, 1) }
  let(:to_date) { Date.new(2023, 12, 31) }
  let(:max_item_count) { 50 }
  let(:service) do
    described_class.new(user, runner_type: runner_type, from_date: from_date, to_date: to_date,
      max_item_count: max_item_count)
  end

  let(:result) { service.execute }

  subject(:data) { result.payload }

  before do
    stub_licensed_features(runner_performance_insights: true)

    insert_ci_builds_to_click_house(builds)
  end

  context 'when user has not enough permissions' do
    let_it_be(:user) { create(:user) }

    it 'returns error' do
      expect(result).to be_error
      expect(result.message).to eq('Insufficient permissions')
      expect(result.reason).to eq(:insufficient_permissions)
    end
  end

  context 'when ClickHouse database is not configured' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'returns error' do
      expect(result).to be_error
      expect(result.message).to eq('ClickHouse database is not configured')
      expect(result.reason).to eq(:db_not_configured)
    end
  end

  it 'exports usage data by runner' do
    is_expected.to eq(
      [{ 'runner_id_bucket' => group_runner.id, 'count_builds' => 5, 'total_duration_in_mins' => 500 }] +
      instance_runners.each_with_index.map do |runner, index|
        { 'runner_id_bucket' => runner.id, 'count_builds' => index + 1, 'total_duration_in_mins' => 10 * (index + 1) }
      end.reverse
    )
  end

  context 'when the number of runners exceeds max_item_count' do
    let(:max_item_count) { 2 }

    it 'exports usage data for the 2 top runners plus aggregate for other projects' do
      is_expected.to eq([
        { 'runner_id_bucket' => group_runner.id, 'count_builds' => 5, 'total_duration_in_mins' => 500 },
        { 'runner_id_bucket' => instance_runners.last.id, 'count_builds' => 3, 'total_duration_in_mins' => 30 },
        { 'runner_id_bucket' => nil, 'count_builds' => 3, 'total_duration_in_mins' => 30 }
      ])
    end
  end

  context 'with group_type runner_type argument specified' do
    let(:runner_type) { :group_type }

    it 'exports usage data for runners of specified type' do
      is_expected.to eq(
        [{ 'runner_id_bucket' => group_runner.id, 'count_builds' => 5, 'total_duration_in_mins' => 500 }]
      )
    end
  end

  context 'with project_type runner_type argument specified' do
    let(:runner_type) { :project_type }

    it 'exports usage data for runners of specified type' do
      is_expected.to eq([])
    end
  end

  context 'when dates are set' do
    let(:from_date) { Date.new(2024, 1, 2) }
    let(:to_date) { Date.new(2024, 1, 2) }

    let(:project) { create(:project) }

    let(:build_before) { create_build(group_runner, Date.new(2024, 1, 1), 14.minutes) }
    let(:build_in_range) { create_build(group_runner, Date.new(2024, 1, 2), 111.minutes) }
    let(:build_overflowing_the_range) { create_build(group_runner, Date.new(2024, 1, 2, 23), 61.minutes) }
    let(:build_after) { create_build(group_runner, Date.new(2024, 1, 3), 15.minutes) }

    let(:builds) { [build_before, build_in_range, build_overflowing_the_range, build_after] }

    it 'only exports usage data for builds created in the date range' do
      is_expected.to contain_exactly(
        { 'runner_id_bucket' => group_runner.id, 'count_builds' => 2, 'total_duration_in_mins' => 172 }
      )
    end
  end

  def create_build(runner, finished_at, duration)
    created_at = finished_at - duration

    build_stubbed(:ci_build,
      :success,
      created_at: created_at,
      queued_at: created_at,
      started_at: created_at,
      finished_at: finished_at,
      project: project,
      runner: runner,
      runner_manager: runner.runner_managers.first)
  end
end
