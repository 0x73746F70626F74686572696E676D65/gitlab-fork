# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240201164432_reindex_merge_request_to_update_analyzer.rb')

RSpec.describe ReindexMergeRequestToUpdateAnalyzer, feature_category: :global_search do
  let(:version) { 20240201164432 }
  let(:migration) { described_class.new(version) }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '#migrate' do
    it 'creates reindexing task with correct target and options' do
      expect { migration.migrate }.to change { Elastic::ReindexingTask.count }.by(1)
      task = Elastic::ReindexingTask.last
      expect(task.targets).to eq(%w[MergeRequest])
      expect(task.options).to eq({ 'skip_pending_migrations_check' => true })
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to eq(true)
    end
  end
end
