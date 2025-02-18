# frozen_string_literal: true

class RemoveDesignManagementRepositoryRegistryForceToRedownloadColumn < Gitlab::Database::Migration[2.2]
  milestone '16.10'
  enable_lock_retries!

  def up
    remove_column :design_management_repository_registry, :force_to_redownload, if_exists: true
  end

  def down
    add_column :design_management_repository_registry,
      :force_to_redownload,
      :boolean,
      default: false,
      null: false,
      if_not_exists: true
  end
end
