# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::WorkItem, feature_category: :global_search do
  describe '#target' do
    it 'returns work_item class' do
      expect(described_class.target.class.name).to eq(WorkItem.class.name)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-work_items')
    end
  end
end
