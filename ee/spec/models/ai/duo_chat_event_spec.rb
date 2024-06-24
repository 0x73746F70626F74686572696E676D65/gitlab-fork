# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoChatEvent, feature_category: :value_stream_management do
  subject(:model) { described_class.new(attributes) }

  let(:attributes) { { event: 'request_duo_chat_response', user: user } }
  let(:user) { build_stubbed(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_inclusion_of(:event).in_array(described_class::EVENTS.keys) }
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(model.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:attributes) do
      super().merge(timestamp: 1.day.ago)
    end

    it 'returns serialized attributes hash' do
      expect(model.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class::EVENTS['request_duo_chat_response'],
        timestamp: 1.day.ago.to_f
      })
    end
  end
end
