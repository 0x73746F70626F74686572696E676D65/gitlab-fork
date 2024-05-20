# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Formats, feature_category: :global_search do
  let(:query_hash) { {} }
  let(:options) { {} }

  describe '#size' do
    subject(:size) { described_class.size(query_hash: query_hash, options: options) }

    it 'returns query_hash' do
      expect(size).to eq(query_hash)
    end

    context 'when count_only is set' do
      let(:options) { { count_only: true } }

      it 'sets size to 0' do
        expect(size).to eq({ size: 0 })
      end
    end
  end

  describe '#source_fields' do
    subject(:source_fields) { described_class.source_fields(query_hash: query_hash, options: options) }

    it 'returns query_hash' do
      expect(source_fields).to eq(query_hash)
    end

    context 'when fiels is set' do
      let(:fields) { %w[id title] }
      let(:options) { { source_fields: fields } }

      it 'sets source to fields' do
        expect(source_fields).to eq({ _source: fields })
      end
    end
  end
end
