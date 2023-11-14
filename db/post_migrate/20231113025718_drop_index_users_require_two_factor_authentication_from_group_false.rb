# frozen_string_literal: true

class DropIndexUsersRequireTwoFactorAuthenticationFromGroupFalse < Gitlab::Database::Migration[2.2]
  milestone '16.7'

  disable_ddl_transaction!

  TABLE_NAME = :users
  INDEX_NAME = :index_users_require_two_factor_authentication_from_group_false

  def up
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end

  def down
    add_concurrent_index TABLE_NAME, :require_two_factor_authentication_from_group,
      where: 'require_two_factor_authentication_from_group = FALSE',
      name: INDEX_NAME
  end
end
