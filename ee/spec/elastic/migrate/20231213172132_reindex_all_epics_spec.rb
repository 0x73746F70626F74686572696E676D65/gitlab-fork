# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231213172132_reindex_all_epics.rb')

RSpec.describe ReindexAllEpics, :elastic, feature_category: :global_search do
  it_behaves_like 'migration reindexes all data' do
    let(:version) { 20231213172132 }
    let(:objects) { create_list(:epic, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 10_000 }
  end
end
