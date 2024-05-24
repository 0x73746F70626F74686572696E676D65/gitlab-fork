# frozen_string_literal: true

class CreateUserAuditEvents < Gitlab::Database::Migration[2.2]
  milestone '17.1'
  enable_lock_retries!

  AUTHOR_ID_CREATED_AT_ID_INDEX = 'idx_user_audit_events_on_author_id_created_at_id'
  USER_ID_AUTHOR_ID_CREATED_AT_ID_INDEX = 'idx_user_audit_events_on_user_id_author_created_at_id'
  USER_ID_CREATED_AT_ID_INDEX = 'idx_user_audit_events_on_project_created_at_id'

  def up
    execute <<-SQL
      CREATE TABLE IF NOT EXISTS user_audit_events (
        id BIGINT NOT NULL DEFAULT nextval('shared_audit_event_id_seq'),
        created_at TIMESTAMP WITH TIME ZONE NOT NULL,
        user_id BIGINT NOT NULL,
        author_id BIGINT NOT NULL,
        target_id BIGINT,
        event_name TEXT,
        details TEXT,
        ip_address INET,
        author_name TEXT,
        entity_path TEXT,
        target_details TEXT,
        target_type TEXT,
        CHECK (char_length(event_name) <= 255),
        CHECK (char_length(author_name) <= 255),
        CHECK (char_length(entity_path) <= 5500),
        CHECK (char_length(target_details) <= 5500),
        CHECK (char_length(target_type) <= 255),
        PRIMARY KEY (id, created_at)
      ) PARTITION BY RANGE (created_at);
    SQL

    # rubocop:disable Migration/AddIndex -- cannot create index on partitioned table concurrently
    add_index :user_audit_events, [:author_id, :created_at, :id], name: AUTHOR_ID_CREATED_AT_ID_INDEX
    add_index :user_audit_events, [:user_id, :author_id, :created_at, :id],
      name: USER_ID_AUTHOR_ID_CREATED_AT_ID_INDEX, order: { id: :desc }
    add_index :user_audit_events, [:user_id, :created_at, :id], name: USER_ID_CREATED_AT_ID_INDEX
    # rubocop:enable Migration/AddIndex
  end

  def down
    drop_table :user_audit_events
  end
end
