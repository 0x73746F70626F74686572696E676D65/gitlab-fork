# frozen_string_literal: true

class ReindexMergeRequestToUpdateAnalyzer < Elastic::Migration
  def migrate
    Elastic::ReindexingTask.create!(targets: %w[MergeRequest], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end
end
