# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) { { user: current_user } }
    let(:event_name) { 'code_suggestion_shown_in_ide' }

    before do
      stub_application_setting(use_clickhouse_for_analytics: true)
    end

    it 'stores new event' do
      event_hash = {
        user: current_user,
        event: event_name
      }
      expect_next_instance_of(Ai::CodeSuggestionsUsage, event_hash) do |instance|
        expect(instance).to receive(:store).once
      end

      track_event
    end

    context 'when extra arguments are present in the context' do
      let(:event_context) { { user: current_user, extra1: 'bar', extra2: 'baz' } }

      it 'ignores extra arguments' do
        expect(Ai::CodeSuggestionsUsage).to receive(:new).with({ event: event_name, user: current_user })
                                                         .once.and_call_original

        track_event
      end
    end

    context 'when clickhouse is not enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: false)
      end

      it 'does not create new events' do
        expect(Ai::CodeSuggestionsUsage).not_to receive(:new)

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
