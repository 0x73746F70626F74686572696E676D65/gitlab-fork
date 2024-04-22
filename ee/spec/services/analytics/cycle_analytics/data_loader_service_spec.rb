# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::DataLoaderService, feature_category: :value_stream_management do
  let_it_be_with_refind(:top_level_group) { create(:group) }

  describe 'validations' do
    let(:namespace) { top_level_group }
    let(:model) { Issue }

    subject(:service_response) { described_class.new(group: namespace, model: model).execute }

    context 'when wrong model is passed' do
      let(:model) { Project }

      it 'returns service error response' do
        expect(service_response).to be_error
        expect(service_response.payload[:reason]).to eq(:invalid_model)
      end
    end

    context 'when license is missing' do
      it 'returns service error response' do
        expect(service_response).to be_error
        expect(service_response.payload[:reason]).to eq(:missing_license)
      end
    end

    context 'when provided namespace is a personal project namespace' do
      let_it_be(:user2) { create(:user) }
      let_it_be(:project) { create(:project, :public, namespace: user2.namespace) }
      let(:namespace) { project.project_namespace }

      it 'returns a successful response' do
        expect(service_response).not_to be_error
        expect(service_response.payload[:reason]).to eq(:model_processed)
      end
    end

    context 'when provided namespace is a personal namespace' do
      let_it_be(:user2) { create(:user) }
      let_it_be(:project) { create(:project, :public, namespace: user2.namespace) }

      let_it_be(:namespace) { user2.namespace }

      let_it_be(:stage1) do
        create(:cycle_analytics_stage, {
          namespace: namespace,
          start_event_identifier: :merge_request_created,
          end_event_identifier: :merge_request_merged
        })
      end

      let_it_be(:current_time) { Time.current }
      let_it_be(:mr) { create(:merge_request, :unique_branches, :with_merged_metrics, created_at: current_time, updated_at: current_time + 2.days, source_project: project) }
      let_it_be(:issue) { create(:issue, project: project, created_at: current_time, closed_at: current_time + 5.minutes, weight: 5) }

      before do
        stub_licensed_features(cycle_analytics_for_projects: true)
      end

      it 'returns a successful response' do
        service_response = described_class.new(group: namespace, model: MergeRequest).execute

        expect(service_response).not_to be_error
        expect(service_response.payload[:reason]).to eq(:model_processed)
        expect(service_response[:context].processed_records).to eq(1)
      end

      it 'creates some aggregated data in the personal namespace project' do
        expect do
          described_class.new(group: namespace, model: MergeRequest).execute
        end.to change { Analytics::CycleAnalytics::MergeRequestStageEvent.count }.by(1)
      end
    end

    context 'when sub-group is given' do
      let(:namespace) { create(:group, parent: top_level_group) }

      it 'returns service error response' do
        stub_licensed_features(cycle_analytics_for_groups: true)

        expect(service_response).to be_error
        expect(service_response.payload[:reason]).to eq(:requires_top_level_group)
      end
    end
  end

  describe 'data loading into stage tables' do
    let_it_be(:sub_group) { create(:group, parent: top_level_group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:project1) { create(:project, :repository, group: top_level_group) }
    let_it_be(:project2) { create(:project, :repository, group: sub_group) }
    let_it_be(:project_outside) { create(:project, group: other_group) }

    let_it_be(:stage1) do
      create(:cycle_analytics_stage, {
        namespace: sub_group,
        start_event_identifier: :merge_request_created,
        end_event_identifier: :merge_request_merged
      })
    end

    let_it_be(:stage2) do
      create(:cycle_analytics_stage, {
        namespace: top_level_group,
        start_event_identifier: :issue_created,
        end_event_identifier: :issue_closed
      })
    end

    let_it_be(:stage_in_other_group) do
      create(:cycle_analytics_stage, {
        namespace: other_group,
        start_event_identifier: :issue_created,
        end_event_identifier: :issue_closed
      })
    end

    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
    end

    it 'loads nothing for Issue model' do
      service_response = described_class.new(group: top_level_group, model: Issue).execute

      expect(service_response).to be_success
      expect(service_response.payload[:reason]).to eq(:model_processed)
      expect(Analytics::CycleAnalytics::IssueStageEvent.count).to eq(0)
      expect(service_response[:context].processed_records).to eq(0)
    end

    it 'loads nothing for MergeRequest model' do
      service_response = described_class.new(group: top_level_group, model: MergeRequest).execute

      expect(service_response).to be_success
      expect(service_response.payload[:reason]).to eq(:model_processed)
      expect(Analytics::CycleAnalytics::MergeRequestStageEvent.count).to eq(0)
      expect(service_response[:context].processed_records).to eq(0)
    end

    context 'when MergeRequest data is present' do
      let_it_be(:current_time) { Time.current }
      let_it_be(:mr1) { create(:merge_request, :unique_branches, :with_merged_metrics, created_at: current_time, updated_at: current_time + 2.days, source_project: project1) }
      let_it_be(:mr2) { create(:merge_request, :unique_branches, :with_merged_metrics, created_at: current_time, updated_at: current_time + 5.days, source_project: project1) }
      let_it_be(:mr3) { create(:merge_request, :unique_branches, :with_merged_metrics, created_at: current_time, updated_at: current_time + 10.days, source_project: project2) }

      let(:durations) do
        {
          mr1 => 2.days.to_i * 1000,
          mr2 => 5.days.to_i * 1000,
          mr3 => 10.days.to_i * 1000
        }
      end

      it 'inserts stage records' do
        expected_data = [mr1, mr2, mr3].map do |mr|
          mr.reload # reload timestamps from the DB
          [
            mr.id,
            mr.project.parent_id,
            mr.project_id,
            mr.created_at,
            mr.metrics.merged_at,
            mr.state_id
          ]
        end

        described_class.new(group: top_level_group, model: MergeRequest).execute

        events = Analytics::CycleAnalytics::MergeRequestStageEvent.all
        event_data = events.map do |event|
          [
            event.merge_request_id,
            event.group_id,
            event.project_id,
            event.start_event_timestamp,
            event.end_event_timestamp,
            Analytics::CycleAnalytics::MergeRequestStageEvent.states[event.state_id]
          ]
        end

        expect(event_data.sort).to match_array(expected_data.sort)
      end

      it 'inserts nothing for group outside of the hierarchy' do
        mr = create(:merge_request, :unique_branches, :with_merged_metrics, source_project: project_outside)

        described_class.new(group: top_level_group, model: MergeRequest).execute

        record_count = Analytics::CycleAnalytics::MergeRequestStageEvent.where(merge_request_id: mr.id).count
        expect(record_count).to eq(0)
      end

      context 'when all records are processed' do
        it 'finishes with model_processed reason' do
          service_response = described_class.new(group: top_level_group, model: MergeRequest).execute

          expect(service_response).to be_success
          expect(service_response.payload[:reason]).to eq(:model_processed)
        end
      end

      context 'when MAX_UPSERT_COUNT is reached' do
        it 'finishes with limit_reached reason' do
          stub_const('Analytics::CycleAnalytics::DataLoaderService::MAX_UPSERT_COUNT', 1)
          stub_const('Analytics::CycleAnalytics::DataLoaderService::BATCH_LIMIT', 1)

          service_response = described_class.new(group: top_level_group, model: MergeRequest).execute

          expect(service_response).to be_success
          expect(service_response.payload[:reason]).to eq(:limit_reached)
        end
      end

      context 'when runtime limit is reached' do
        it 'finishes with limit_reached reason' do
          first_monotonic_time = 100
          second_monotonic_time = first_monotonic_time + Gitlab::Metrics::RuntimeLimiter::DEFAULT_MAX_RUNTIME.to_i + 10

          # 1. when initializing the runtime limiter
          # 2. when start the processing
          # 3. when calling over_time? within the rate limiter
          # 4. when calculating the aggregation duration
          expect(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(first_monotonic_time, first_monotonic_time, second_monotonic_time, second_monotonic_time)

          service_response = described_class.new(group: top_level_group, model: MergeRequest).execute

          expect(service_response).to be_success
          expect(service_response.payload[:reason]).to eq(:limit_reached)
        end
      end

      context 'when cursor is given' do
        it 'continues processing the records from the cursor' do
          stub_const('Analytics::CycleAnalytics::DataLoaderService::MAX_UPSERT_COUNT', 1)
          stub_const('Analytics::CycleAnalytics::DataLoaderService::BATCH_LIMIT', 1)

          service_response = described_class.new(group: top_level_group, model: MergeRequest).execute
          ctx = service_response.payload[:context]

          expect(Analytics::CycleAnalytics::MergeRequestStageEvent.count).to eq(1)

          described_class.new(group: top_level_group, model: MergeRequest, context: ctx).execute

          expect(Analytics::CycleAnalytics::MergeRequestStageEvent.count).to eq(2)
          expect(ctx.processed_records).to eq(2)
          expect(ctx.runtime).to be > 0
        end
      end
    end

    context 'when Issue data is present' do
      let_it_be(:iteration) { create(:iteration, group: top_level_group) }
      let_it_be(:creation_time) { Time.current }
      let_it_be(:issue1) { create(:issue, project: project1, created_at: creation_time, closed_at: creation_time + 5.minutes, weight: 5) }
      let_it_be(:issue2) { create(:issue, project: project1, created_at: creation_time, closed_at: creation_time + 10.minutes) }
      let_it_be(:issue3) { create(:issue, project: project2, created_at: creation_time, closed_at: creation_time + 15.minutes, weight: 2, iteration: iteration) }
      # invalid the creation time would be later than closed_at, this should not be aggregated
      let_it_be(:issue4) { create(:issue, project: project2, created_at: creation_time, closed_at: creation_time - 5.minutes) }

      let(:durations) do
        {
          issue1 => 5.minutes.to_i * 1000,
          issue2 => 10.minutes.to_i * 1000,
          issue3 => 15.minutes.to_i * 1000
        }
      end

      it 'inserts stage records' do
        expected_data = [issue1, issue2, issue3].map do |issue|
          issue.reload
          [
            issue.id,
            issue.project.parent_id,
            issue.project_id,
            issue.created_at,
            issue.closed_at,
            issue.state_id,
            issue.weight,
            issue.sprint_id,
            durations.fetch(issue)
          ]
        end

        described_class.new(group: top_level_group, model: Issue).execute

        events = Analytics::CycleAnalytics::IssueStageEvent.all
        event_data = events.map do |event|
          [
            event.issue_id,
            event.group_id,
            event.project_id,
            event.start_event_timestamp,
            event.end_event_timestamp,
            Analytics::CycleAnalytics::IssueStageEvent.states[event.state_id],
            event.weight,
            event.sprint_id,
            event.duration_in_milliseconds
          ]
        end

        expect(event_data.sort).to match_array(expected_data.sort)
      end
    end
  end

  describe 'data loading for stages with label based events' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let_it_be(:label1) { create(:group_label, group: group) }

    let_it_be(:issue1) { create(:issue, project: project) }
    let_it_be(:issue2) { create(:issue, project: project) }

    let_it_be(:stage1) do
      create(:cycle_analytics_stage, {
        namespace: group,
        start_event_identifier: :issue_label_added,
        start_event_label: label1,
        end_event_identifier: :issue_label_removed,
        end_event_label: label1
      })
    end

    let_it_be(:stage2) do
      create(:cycle_analytics_stage, {
        namespace: group,
        start_event_identifier: :issue_created,
        end_event_identifier: :issue_label_removed,
        end_event_label: label1
      })
    end

    let_it_be(:stage3) do
      create(:cycle_analytics_stage, {
        namespace: group,
        start_event_identifier: :issue_label_added,
        start_event_label: label1,
        end_event_identifier: :issue_closed
      })
    end

    let_it_be(:start_time) { 5.days.ago }

    subject(:collected_events) { Analytics::CycleAnalytics::IssueStageEvent.where(stage_event_hash_id: stage1.stage_event_hash_id) }

    before do
      stub_licensed_features(cycle_analytics_for_groups: true)

      # add and remove after 10 minutes
      create(:resource_label_event, action: :add, issue: issue1, label: label1, created_at: start_time)
      create(:resource_label_event, action: :remove, issue: issue1, label: label1, created_at: start_time + 10.minutes)

      # add and remove after 5 minutes
      create(:resource_label_event, action: :add, issue: issue1, label: label1, created_at: start_time + 1.hour)
      create(:resource_label_event, action: :remove, issue: issue1, label: label1, created_at: start_time + 1.hour + 5.minutes)

      # add and remove after 15 minutes
      create(:resource_label_event, action: :add, issue: issue1, label: label1, created_at: start_time + 10.hours)
      create(:resource_label_event, action: :remove, issue: issue1, label: label1, created_at: start_time + 10.hours + 15.minutes)
    end

    it 'calculates the sum of durations between the start - end events' do
      described_class.new(group: group, model: Issue).execute

      expect(collected_events.size).to eq(1)

      event = collected_events.first
      expect(event.issue_id).to eq(issue1.id)
      expect(event.start_event_timestamp).to be_within(5.seconds).of(start_time)
      expect(event.end_event_timestamp).to be_within(5.seconds).of(start_time + 10.hours + 15.minutes)
      expect(event.duration_in_milliseconds).to eq(30.minutes.in_milliseconds.to_i)
    end

    context 'when there is a another start event without end event' do
      before do
        create(:resource_label_event, action: :add, issue: issue1, label: label1, created_at: start_time + 20.hours)
      end

      it 'does not take unfinished event pairs into the calculation' do
        described_class.new(group: group, model: Issue).execute

        expect(collected_events.size).to eq(1)

        event = collected_events.first
        expect(event.issue_id).to eq(issue1.id)
        expect(event.start_event_timestamp).to be_within(5.seconds).of(start_time)
        expect(event.end_event_timestamp).to be_within(5.seconds).of(start_time + 10.hours + 15.minutes)
        expect(event.duration_in_milliseconds).to eq((10.hours + 15.minutes).in_milliseconds)
      end
    end

    context 'when the calculated duration is 0' do
      before do
        create(:resource_label_event, action: :add, issue: issue2, label: label1, created_at: start_time)
        create(:resource_label_event, action: :remove, issue: issue2, label: label1, created_at: start_time)
      end

      it 'does not include the issue in the aggregation' do
        expect(collected_events.pluck(:issue_id)).not_to include(issue2.id)
      end
    end

    context 'when the start event is a non-label event' do
      before do
        issue1.update!(created_at: start_time)
      end

      it 'uses the last timestamp from end event timestamps' do
        described_class.new(group: group, model: Issue).execute

        event_for_issue = Analytics::CycleAnalytics::IssueStageEvent
          .where(stage_event_hash_id: stage2.stage_event_hash_id, issue_id: issue1.id)
          .first!

        expect(event_for_issue.duration_in_milliseconds).to eq((10.hours + 15.minutes).in_milliseconds)
      end
    end

    context 'when the end event is a non-label event' do
      before do
        issue1.update!(closed_at: start_time + 20.hours)
      end

      it 'uses the last timestamp from end event timestamps' do
        described_class.new(group: group, model: Issue).execute

        event_for_issue = Analytics::CycleAnalytics::IssueStageEvent
          .where(stage_event_hash_id: stage3.stage_event_hash_id, issue_id: issue1.id)
          .first!

        expect(event_for_issue.duration_in_milliseconds).to eq(20.hours.in_milliseconds)
      end
    end
  end
end
