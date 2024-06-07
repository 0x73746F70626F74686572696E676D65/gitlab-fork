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
      let!(:usage1) { build(:code_suggestions_usage).tap(&:store) }
      let!(:usage2) { build(:code_suggestions_usage).tap(&:store) }
      let!(:usage3) { build(:code_suggestions_usage).tap(&:store) }

      it 'inserts all rows' do
        status = job.perform

        expect(status).to eq({ status: :processed, inserted_rows: 3 })

        expect(inserted_records).to match([
          hash_including('user_id' => usage1.user.id),
          hash_including('user_id' => usage2.user.id),
          hash_including('user_id' => usage3.user.id)
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

          expect(ClickHouse::WriteBuffer.pop('code_suggestion_usages', 100).size).to eq(3)
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
            hash_including('user_id' => usage1.user.id),
            hash_including('user_id' => usage2.user.id)
          ])
        end
      end
    end

    context 'when data has 2 different sets of fields', :freeze_time do
      let!(:usage1_hash) do
        {
          user_id: 1,
          timestamp: 1.day.ago.to_f,
          event: 1
        }
      end

      let!(:usage2_hash) do
        {
          user_id: 2,
          timestamp: 2.days.ago.to_f,
          event: 2,
          namespace_path: '2/'
        }
      end

      before do
        ::ClickHouse::WriteBuffer.add('code_suggestion_usages', usage1_hash)
        ::ClickHouse::WriteBuffer.add('code_suggestion_usages', usage2_hash)
      end

      it 'runs separate insert query for each attributes group' do
        expect(ClickHouse::Client).to receive(:insert_csv).twice.and_call_original

        status = job.perform

        expect(status).to eq({ status: :processed, inserted_rows: 2 })

        expect(inserted_records).to match([
          hash_including('user_id' => 1),
          hash_including('user_id' => 2)
        ])
      end
    end
  end
end
