# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231130202203_reindex_issues_to_update_analyzer.rb')

RSpec.describe ReindexIssuesToUpdateAnalyzer, feature_category: :global_search do
  let(:version) { 20231130202203 }
  let(:migration) { described_class.new(version) }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '.migrate' do
    it 'creates reindexing task' do
      expect { migration.migrate }.to change { Elastic::ReindexingTask.count }.by(1)
    end
  end

  describe 'completed?' do
    it 'always returns true' do
      expect(migration.completed?).to eq(true)
    end
  end
end
