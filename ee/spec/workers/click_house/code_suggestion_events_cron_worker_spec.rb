# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::CodeSuggestionEventsCronWorker, feature_category: :value_stream_management do
  let(:job) { described_class.new }

  context 'when ClickHouse is disabled for analytics' do
    before do
      stub_application_setting(use_clickhouse_for_analytics: false)
    end

    it 'does nothing' do
      expect(Gitlab::Metrics::RuntimeLimiter).not_to receive(:new)

      job.perform
    end
  end

  context 'when code_suggestion_events_in_click_house feature flag is disabled' do
    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
      stub_feature_flags(code_suggestion_events_in_click_house: false)
    end

    it 'does nothing' do
      expect(Gitlab::Metrics::RuntimeLimiter).not_to receive(:new)

      job.perform
    end
  end

  context 'when ClickHouse is enabled', :click_house, :clean_gitlab_redis_shared_state do
    let(:connection) { ClickHouse::Connection.new(:main) }

    subject(:inserted_records) { connection.select('SELECT * FROM code_suggestion_usages FINAL ORDER BY user_id ASC') }

    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    it 'does not insert anything' do
      job.perform

      expect(inserted_records).to be_empty
    end

    context 'when data is present' do
      before do
        Gitlab::Tracking::AiTracking.track_event('code_suggestions_requested', { user_id: 1 })
        Gitlab::Tracking::AiTracking.track_event('code_suggestions_requested', { user_id: 2 })
        Gitlab::Tracking::AiTracking.track_event('code_suggestions_requested', { user_id: 3 })
      end

      it 'inserts all rows' do
        status = job.perform

        expect(status).to eq({ status: :processed, inserted_rows: 3 })

        event = Gitlab::Tracking::AiTracking::EVENTS['code_suggestions_requested']
        expect(inserted_records).to match([
          hash_including('user_id' => 1, 'event' => event),
          hash_including('user_id' => 2, 'event' => event),
          hash_including('user_id' => 3, 'event' => event)
        ])
      end

      context 'when looping twice' do
        it 'inserts all rows' do
          stub_const("#{described_class.name}::BATCH_SIZE", 2)

          status = job.perform

          expect(status).to eq({ status: :processed, inserted_rows: 3 })
        end
      end

      context 'when pinging ClickHouse fails' do
        it 'does not take anything from buffer' do
          allow_next_instance_of(ClickHouse::Connection) do |connection|
            expect(connection).to receive(:ping).and_raise(Errno::ECONNREFUSED)
          end

          expect { job.perform }.to raise_error(Errno::ECONNREFUSED)

          expect(ClickHouse::WriteBuffer.pop_events(100).size).to eq(3)
        end
      end

      context 'when time limit is up' do
        it 'returns over_time status' do
          stub_const("#{described_class.name}::BATCH_SIZE", 1)

          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
            allow(limiter).to receive(:over_time?).and_return(false, false, true)
          end

          status = job.perform

          expect(status).to eq({ status: :over_time, inserted_rows: 2 })

          expect(inserted_records).to match([
            hash_including('user_id' => 1),
            hash_including('user_id' => 2)
          ])
        end
      end
    end
  end
end
