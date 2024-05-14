# frozen_string_literal: true

class RemoveEpicsBasedOnSchemaVersion < Elastic::Migration
  include ::Search::Elastic::MigrationDeleteBasedOnSchemaVersion

  DOCUMENT_TYPE = Epic

  batch_size 5000
  batched!
  throttle_delay 3.minutes
  retry_on_failure

  def schema_version
    24_01
  end
end

RemoveEpicsBasedOnSchemaVersion.prepend ::Elastic::MigrationObsolete
