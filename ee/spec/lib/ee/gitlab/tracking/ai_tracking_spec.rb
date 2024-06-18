# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) { { user: current_user } }
    let(:event_name) { 'some_unknown_event' }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    shared_examples 'common event tracking for' do |model_class|
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name
        }
      end

      context 'when clickhouse is disabled for analytics' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'does not create new events' do
          expect(model_class).not_to receive(:new)

          track_event
        end
      end

      it 'stores new event' do
        expect_next_instance_of(model_class, expected_event_hash) do |instance|
          expect(instance).to receive(:store).once
        end

        track_event
      end

      context 'when extra arguments are present in the context' do
        let(:event_context) { super().merge({ extra1: 'bar', extra2: 'baz' }) }

        it 'ignores extra arguments' do
          expect(model_class).to receive(:new).with(expected_event_hash).once.and_call_original

          track_event
        end
      end
    end

    it_behaves_like 'common event tracking for', Ai::CodeSuggestionsUsage do
      let(:event_name) { 'code_suggestion_shown_in_ide' }
    end

    it_behaves_like 'common event tracking for', Ai::DuoChatEvent do
      let(:event_name) { 'request_duo_chat_response' }
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
