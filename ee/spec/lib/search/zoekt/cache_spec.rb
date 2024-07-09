# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Cache, :clean_gitlab_redis_cache, feature_category: :global_search do
  let(:default_options) do
    { per_page: 20, max_per_page: 40, search_mode: :regex }
  end

  let(:query) { 'foo' }
  let_it_be(:user1) { build(:user, id: 1) }
  let(:page) { 1 }
  let(:project_ids) { [3, 2, 1] }
  let(:search_results) { { 0 => { project_id: 1 }, 1 => { project_id: 2 }, 2 => { project_id: 3 } } }
  let(:total_count) { 3 }
  let(:response) { [search_results, total_count] }

  subject(:cache) do
    described_class.new(query, **default_options.merge(current_user: user1, project_ids: project_ids, page: page))
  end

  before do
    stub_const("#{described_class.name}::MAX_PAGES", 2)
  end

  describe '#cache_key' do
    let(:uniq_examples) do
      [
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [3, 2], page: 1 },
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [3, 2], page: 1, per_page: 10 },
        { current_user: build(:user, id: 1), query: 'bar', project_ids: [3, 2], page: 1 },
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [2], page: 1 },
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [3, 2], page: 2 },
        { current_user: build(:user, id: 2), query: 'foo', project_ids: [3, 2], page: 1 },
        { current_user: build(:user, id: nil), query: 'foo', project_ids: [3, 2], page: 1 }
      ]
    end

    let(:duplicate_examples) do
      [
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [1, 3, 2], page: 1, per_page: 20 },
        { current_user: build(:user, id: 1), query: 'foo', project_ids: [2, 3, 1], page: 1, per_page: 20 }
      ]
    end

    it 'returns unique cache keys for different queries' do
      result = {}

      uniq_examples.each do |e|
        cache_key = described_class.new(e[:query], **default_options.merge(e.except(:query))).cache_key

        result[cache_key] ||= []
        result[cache_key] << e
      end

      result.each do |key, examples|
        expect(examples.size).to eq(1), "#{key} has duplicate examples: #{examples}"
      end
    end

    it 'returns the same cache key for duplicate queries' do
      cache_keys = duplicate_examples.map do |e|
        described_class.new(e[:query], **default_options.merge(e.except(:query))).cache_key
      end

      expect(cache_keys.uniq.size).to eq(1)
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(zoekt_cache_search_responses: false)
    end

    describe '#enabled?' do
      it 'returns false' do
        expect(cache.enabled?).to be false
      end
    end

    describe '#fetch' do
      it 'does not use cache' do
        expect(cache).not_to receive(:read_cache)
        expect(response).to receive(:length)

        data = cache.fetch do
          response.length
          response
        end

        expect(data).to eq(response)
      end
    end
  end

  context 'when feature flag is enabled' do
    before do
      stub_feature_flags(zoekt_cache_search_responses: true)
    end

    describe '#enabled?' do
      it 'returns true' do
        expect(cache.enabled?).to be true
      end

      context 'when project_ids is empty' do
        let(:project_ids) { [] }

        it 'returns false' do
          expect(cache.enabled?).to be false
        end
      end
    end

    describe '#fetch' do
      it 'reads and updates cache' do
        expect(cache).to receive(:read_cache)
        expect(cache).to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(described_class::MAX_PAGES)
          response
        end

        expect(data).to eq(response)
      end

      context 'when page is higher than the limit' do
        let(:page) { 3 }

        it 'sets the correct page limit' do
          data = cache.fetch do |page_limit|
            expect(page_limit).to eq(page)
            response
          end

          expect(data).to eq(response)
        end
      end
    end
  end
end
