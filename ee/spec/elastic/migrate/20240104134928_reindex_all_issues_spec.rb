# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240104134928_reindex_all_issues.rb')

RSpec.describe ReindexAllIssues, :elastic, feature_category: :global_search do
  it_behaves_like 'migration reindexes all data' do
    let(:version) { 20240104134928 }
    let(:objects) { create_list(:issue, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 50_000 }
  end
end
