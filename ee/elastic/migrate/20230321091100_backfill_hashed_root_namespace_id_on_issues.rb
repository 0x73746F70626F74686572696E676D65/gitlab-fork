# frozen_string_literal: true

class BackfillHashedRootNamespaceIdOnIssues < Elastic::Migration
  include Elastic::MigrationBackfillHelper

  batched!
  batch_size 9_000
  throttle_delay 1.minute

  DOCUMENT_TYPE = Issue
  UPDATE_BATCH_SIZE = 100

  private

  def field_name
    'hashed_root_namespace_id'
  end
end

BackfillHashedRootNamespaceIdOnIssues.prepend ::Elastic::MigrationObsolete
