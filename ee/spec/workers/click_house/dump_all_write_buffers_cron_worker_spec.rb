# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::DumpAllWriteBuffersCronWorker, feature_category: :database do
  let(:job) { described_class.new }

  context 'when ClickHouse is disabled for analytics' do
    before do
      stub_application_setting(use_clickhouse_for_analytics: false)
    end

    it 'does nothing' do
      expect(ClickHouse::DumpWriteBufferWorker).not_to receive(:perform_async)

      job.perform
    end
  end

  context 'when ClickHouse is enabled', :click_house do
    let(:clickhouse_model) do
      Class.new(ClickHouseModel) do
        self.table_name = 'test_table'
      end
    end

    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    it 'schedules DumpWriteBufferWorker for each clickhouse model' do
      allow(ClickHouseModel).to receive(:descendants).and_return([clickhouse_model])
      expect(ClickHouse::DumpWriteBufferWorker).to receive(:perform_async).with('test_table')

      job.perform
    end
  end
end
