# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20240119130539_reindex_notes_to_update_analyzer.rb')

RSpec.describe ReindexNotesToUpdateAnalyzer, feature_category: :global_search do
  let(:version) { 20240119130539 }
  let(:migration) { described_class.new(version) }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '#migrate' do
    it 'creates reindexing task with correct target and options' do
      expect { migration.migrate }.to change { Elastic::ReindexingTask.count }.by(1)
      task = Elastic::ReindexingTask.last
      expect(task.targets).to eq(%w[Note])
      expect(task.options).to eq({ 'skip_pending_migrations_check' => true })
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to eq(true)
    end
  end
end
