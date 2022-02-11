# frozen_string_literal: true

class AddTemporaryIndexForBackfillIntegrationsEnableSslVerification < Gitlab::Database::Migration[1.0]
  INDEX_NAME = 'tmp_index_integrations_on_id_where_type_droneci_or_teamcity'
  INDEX_CONDITION = "type IN ('DroneCiService', 'TeamcityService') AND properties IS NOT NULL"

  disable_ddl_transaction!

  def up
    # this index is used in 20220209121435_backfill_integrations_enable_ssl_verification
    add_concurrent_index :integrations, :id, where: INDEX_CONDITION, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :integrations, INDEX_NAME
  end
end
