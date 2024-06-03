# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ProcessEmbeddingBookkeepingService, feature_category: :global_search do
  describe '.redis_set_key' do
    specify { expect(described_class.redis_set_key(7)).to eq('elastic:embedding:updates:7:zset') }
  end

  describe '.redis_score_key' do
    specify { expect(described_class.redis_score_key(7)).to eq('elastic:embedding:updates:7:score') }
  end

  describe '.shard_limit' do
    it 'is equal to 19' do
      expect(described_class.shard_limit).to eq(19)
    end
  end
end
