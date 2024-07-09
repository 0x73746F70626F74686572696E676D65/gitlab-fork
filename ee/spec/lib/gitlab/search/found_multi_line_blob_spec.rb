# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::FoundMultiLineBlob, feature_category: :global_search do
  describe '#initialize and read the attributes' do
    it 'can initialize an instance and read the attributes' do
      instance = described_class.new(
        path: 'p', chunks: [], file_url: 'f', blame_url: 'b', match_count_total: 5, match_count: 3, project_path: 'path'
      )
      expect(instance).to have_attributes(
        path: 'p', chunks: [], file_url: 'f', blame_url: 'b', match_count_total: 5, match_count: 3, project_path: 'path'
      )
    end
  end
end
