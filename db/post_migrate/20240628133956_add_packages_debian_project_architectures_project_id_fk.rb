# frozen_string_literal: true

class AddPackagesDebianProjectArchitecturesProjectIdFk < Gitlab::Database::Migration[2.2]
  milestone '17.2'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :packages_debian_project_architectures, :projects, column: :project_id,
      on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :packages_debian_project_architectures, column: :project_id
    end
  end
end
