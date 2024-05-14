# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) { { user: current_user } }
    let(:event_name) { 'code_suggestions_requested' }

    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    it 'writes to ClickHouse buffer with event data' do
      expect(::ClickHouse::WriteBuffer).to receive(:write_event).with({
        user_id: current_user.id,
        timestamp: Time.current,
        event: 1
      }).once

      track_event
    end

    context 'when :ai_tracking_data_gathering feature flag is disabled' do
      before do
        stub_feature_flags(ai_tracking_data_gathering: false)
      end

      it 'does not write to ClickHouse buffer' do
        expect(::ClickHouse::WriteBuffer).not_to receive(:write_event)

        track_event
      end
    end

    context 'when clickhouse is not enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: false)
      end

      it 'does not write to ClickHouse buffer' do
        expect(::ClickHouse::WriteBuffer).not_to receive(:write_event)

        track_event
      end
    end

    context 'when event is not from AiTracking list' do
      let(:event_name) { 'something_irrelevant' }

      it 'does not write to ClickHouse buffer' do
        expect(::ClickHouse::WriteBuffer).not_to receive(:write_event)

        track_event
      end
    end

    context 'when context has timestamp overridden' do
      let(:event_context) { { user: current_user, timestamp: 3.days.ago.to_s } }

      it 'respects overridden timestamp' do
        expect(::ClickHouse::WriteBuffer).to receive(:write_event).with({
          user_id: current_user.id,
          timestamp: 3.days.ago,
          event: 1
        }).once

        track_event
      end
    end
  end

  describe 'track_via_code_suggestions?' do
    let(:current_user) { build_stubbed(:user) }

    before do
      stub_feature_flags(code_suggestions_direct_completions: false)
    end

    it 'is true for code_suggestions_requested event' do
      expect(described_class.track_via_code_suggestions?('code_suggestions_requested', current_user)).to be_truthy
    end

    it 'is false with different event' do
      expect(described_class.track_via_code_suggestions?('irrelevant_event', current_user)).to be_falsey
    end

    context 'with feature flag enabled' do
      before do
        stub_feature_flags(code_suggestions_direct_completions: true)
      end

      it 'is false' do
        expect(described_class.track_via_code_suggestions?('code_suggestions_requested', current_user)).to be_falsey
      end
    end
  end
end
