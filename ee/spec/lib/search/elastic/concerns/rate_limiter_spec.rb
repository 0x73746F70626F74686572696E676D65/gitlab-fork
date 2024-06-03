# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Concerns::RateLimiter, feature_category: :global_search do
  subject(:instance) { Class.new.include(described_class).new }

  describe '#embeddings_throttled?' do
    it 'calls ApplicationRateLimiter.peek' do
      expect(::Gitlab::ApplicationRateLimiter)
        .to receive(:peek).with(described_class::ENDPOINT, scope: nil, threshold: 315.0)
        .and_call_original

      expect(instance).not_to be_embeddings_throttled
    end

    context 'when endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_return(true)
      end

      it 'returns true' do
        expect(instance).to be_embeddings_throttled
      end
    end
  end

  describe '#embeddings_throttled_after_increment?' do
    it 'calls ApplicationRateLimiter.throttled?' do
      expect(::Gitlab::ApplicationRateLimiter)
        .to receive(:throttled?).with(described_class::ENDPOINT, scope: nil, threshold: 315.0)
        .and_call_original

      expect(instance).not_to be_embeddings_throttled_after_increment
    end

    context 'when endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'returns true' do
        expect(instance).to be_embeddings_throttled_after_increment
      end
    end
  end

  describe '#threshold' do
    it 'is equal to 315.0 when endpoint threshold is 450' do
      expect(::Gitlab::ApplicationRateLimiter).to receive(:rate_limits).and_call_original

      expect(instance.threshold).to eq(315.0)
    end
  end
end
