# frozen_string_literal: true

class BackfillArchivedOnMergeRequests < Elastic::Migration
  include Elastic::MigrationBackfillHelper

  batched!
  batch_size 9_000
  throttle_delay 1.minute

  DOCUMENT_TYPE = MergeRequest
  UPDATE_BATCH_SIZE = 100

  private

  def field_name
    'archived'
  end
end

BackfillArchivedOnMergeRequests.prepend ::Elastic::MigrationObsolete
