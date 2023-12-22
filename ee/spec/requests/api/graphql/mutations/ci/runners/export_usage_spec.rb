# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RunnersExportUsage', :click_house, :enable_admin_mode, :sidekiq_inline, :freeze_time,
  feature_category: :fleet_visibility do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:group_runner) { create(:ci_runner, :group) }
  let_it_be(:start_time) { 1.month.ago }
  let_it_be(:build1) do
    build(:ci_build, :success, created_at: start_time, queued_at: start_time, started_at: start_time,
      finished_at: start_time + 10.minutes, runner: instance_runner)
  end

  let_it_be(:build2) do
    build(:ci_build, :success, created_at: start_time, queued_at: start_time, started_at: start_time,
      finished_at: start_time + 10.minutes, runner: group_runner)
  end

  let(:runner_type) { 'group_type' }
  let(:mutation_args) do
    {
      type: runner_type.upcase,
      from_date: Date.new(2023, 11, 1),
      to_date: Date.new(2023, 11, 30),
      max_project_count: 7
    }
  end

  let(:mutation) do
    graphql_mutation(:runners_export_usage, mutation_args) do
      <<~QL
        errors
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:runners_export_usage) }

  subject(:post_response) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(runner_performance_insights: true)
    travel_to DateTime.new(2023, 12, 14)

    insert_ci_builds_to_click_house([build1, build2])
  end

  it 'sends email with report' do
    expect(::Ci::Runners::ExportUsageCsvWorker).to receive(:perform_async)
      .with(current_user.id, {
        runner_type: ::Ci::Runner.runner_types[runner_type],
        **mutation_args.slice(:from_date, :to_date, :max_project_count)
      }).and_call_original
    expect(Notify).to receive(:runner_usage_by_project_csv_email)
      .with(
        user: current_user, from_date: mutation_args[:from_date], to_date: mutation_args[:to_date],
        csv_data: anything, export_status: anything
      ) do |args|
        expect(args.dig(:export_status, :rows_written)).to eq 1

        parsed_csv = CSV.parse(args[:csv_data], headers: true)
        expect(parsed_csv[0]['Project ID']).to eq build2.project.id.to_s

        instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      end

    post_response
    expect_graphql_errors_to_be_empty
  end

  context 'with default args' do
    let(:mutation_args) { {} }

    it 'sends email with report' do
      expect(::Ci::Runners::ExportUsageCsvWorker).to receive(:perform_async)
        .with(current_user.id, {
          runner_type: nil, from_date: Date.new(2023, 11, 1), to_date: Date.new(2023, 11, 30), max_project_count: 1_000
        }).and_call_original

      post_response
      expect_graphql_errors_to_be_empty
    end
  end

  context 'with only from_date' do
    let(:mutation_args) { { from_date: Date.new(2023, 9, 1) } }

    it 'sends email with report of the month of September' do
      expect(::Ci::Runners::ExportUsageCsvWorker).to receive(:perform_async)
        .with(current_user.id, {
          runner_type: nil, from_date: Date.new(2023, 9, 1), to_date: Date.new(2023, 9, 30), max_project_count: 1_000
        }).and_call_original

      post_response
      expect_graphql_errors_to_be_empty
    end
  end

  context 'when max_project_count is out-of-range' do
    context 'and is below acceptable range' do
      let(:mutation_args) { { type: runner_type.upcase, max_project_count: 0 } }

      it 'returns an error' do
        post_response
        expect_graphql_errors_to_include('maxProjectCount must be between 1 and 1000')
      end
    end

    context 'and is above acceptable range' do
      let(:mutation_args) do
        { type: runner_type.upcase, max_project_count: ::Ci::Runners::GenerateUsageCsvService::MAX_PROJECT_COUNT + 1 }
      end

      it 'returns an error' do
        post_response
        expect_graphql_errors_to_include('maxProjectCount must be between 1 and 1000')
      end
    end
  end

  context 'when feature is not available' do
    before do
      stub_licensed_features(runner_performance_insights: false)
    end

    it 'returns an error' do
      post_response

      expect(graphql_errors)
        .to include(a_hash_including('message' => "The resource that you are attempting to access does " \
                                                  "not exist or you don't have permission to perform this action"))
    end
  end
end
