# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionsUsage, feature_category: :value_stream_management do
  subject(:model) { described_class.new(**attributes) }

  let(:attributes) { { event: 'code_suggestion_shown_in_ide', user: user } }
  let(:user) { build_stubbed(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_inclusion_of(:event).in_array(described_class::EVENTS.keys) }
    it { is_expected.to validate_numericality_of(:suggestion_size).only_integer.is_greater_than_or_equal_to(0) }
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
      super().merge(timestamp: 1.day.ago, suggestion_size: 3, language: 'foo', unique_tracking_id: 'bar')
    end

    it 'returns serialized attributes hash' do
      expect(model.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class::EVENTS['code_suggestion_shown_in_ide'],
        timestamp: 1.day.ago.to_f,
        suggestion_size: 3,
        language: 'foo',
        unique_tracking_id: 'bar'
      })
    end
  end
end
