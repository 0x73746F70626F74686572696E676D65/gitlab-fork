# frozen_string_literal: true

class ReindexIssueToUpdateAnalyzerForTitle < Elastic::Migration
  def migrate
    Elastic::ReindexingTask.create!(targets: %w[Issue], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end
end
