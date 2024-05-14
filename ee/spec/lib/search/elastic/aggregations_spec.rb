# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Aggregations, feature_category: :global_search do
  let(:query_hash) { {} }

  describe '#by_label_ids' do
    it 'adds size and aggs to query_hash' do
      expect(described_class.by_label_ids(query_hash: query_hash)).to eq({ size: 0,
        aggs: {
          'labels' => {
            terms: {
              field: 'label_ids',
              size: described_class::AGGREGATION_LIMIT
            }
          }
        } })
    end

    context 'when max_size is passed' do
      it 'overrides the aggregation size' do
        expect(described_class.by_label_ids(query_hash: query_hash, max_size: 5)).to eq({ size: 0,
          aggs: {
            'labels' => {
              terms: {
                field: 'label_ids',
                size: 5
              }
            }
          } })
      end
    end
  end
end
