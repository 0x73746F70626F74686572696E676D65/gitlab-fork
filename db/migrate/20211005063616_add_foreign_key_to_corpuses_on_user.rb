# frozen_string_literal: true

class AddForeignKeyToCorpusesOnUser < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :coverage_fuzzing_corpuses, :users, column: :user_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :coverage_fuzzing_corpuses, column: :user_id
    end
  end
end
