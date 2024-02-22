# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'new tables missing sharding_key', feature_category: :cell do
  include ShardingKeySpecHelpers

  let(:allowed_sharding_key_referenced_tables) { %w[projects namespaces organizations] }
  let(:allowed_to_be_missing_foreign_key) do
    [
      'ci_job_artifact_states.job_artifact_id'
    ]
  end

  let(:allowed_to_be_missing_not_null) do
    [
      # column is missing NOT NULL constraint, but `belongs_to` association has `optional: false`, so we are good.
      'vulnerability_findings_remediations.vulnerability_occurrence_id'
    ]
  end

  it 'must reference an allowed referenced table' do
    desired_sharding_key_entries.each do |entry|
      entry.desired_sharding_key.each do |_column, details|
        references = details['references']
        expect(references).to be_in(allowed_sharding_key_referenced_tables),
          error_message_incorrect_reference(entry.table_name, references)
      end
    end
  end

  context 'for tables that already have a backfilled, non-nullable sharding key on their parent' do
    it 'must be possible to backfill it via backfill_via' do
      desired_sharding_key_entries_not_awaiting_backfill_on_parent.each do |entry|
        entry.desired_sharding_key.each do |desired_column, details|
          table = entry.table_name
          connection = Gitlab::Database.schemas_to_base_models[entry.gitlab_schema].first.connection
          sharding_key = desired_column
          parent = details['backfill_via']['parent']
          foreign_key = parent['foreign_key']
          parent_table = parent['table']
          parent_sharding_key = parent['sharding_key']

          connection.execute("ALTER TABLE #{table} ADD COLUMN IF NOT EXISTS #{sharding_key} bigint")

          # Confirming it at least produces a valid query
          connection.execute <<~SQL
                             EXPLAIN UPDATE #{table}
                             SET #{sharding_key} = #{parent_table}.#{parent_sharding_key}
                             FROM #{parent_table}
                             WHERE #{table}.#{foreign_key} = #{parent_table}.id
          SQL
        end
      end
    end

    it 'the parent.belongs_to must be a model with the parent.sharding_key column' do
      desired_sharding_key_entries_not_awaiting_backfill_on_parent.each do |entry|
        model = entry.classes.first.constantize
        entry.desired_sharding_key.each do |_column, details|
          parent = details['backfill_via']['parent']
          parent_sharding_key = parent['sharding_key']
          belongs_to = parent['belongs_to']
          parent_association = model.reflect_on_association(belongs_to)
          expect(parent_association).not_to be_nil,
            "Invalid backfill_via.parent.belongs_to: #{belongs_to} in db/docs for #{entry.table_name}"
          parent_columns = parent_association.klass.columns.map(&:name)

          expect(parent_columns).to include(parent_sharding_key)
        end
      end
    end

    it 'belongs to parent association via a foreign key column', :aggregate_failures do
      all_tables_to_desired_sharding_key.each do |table_name, desired_sharding_key|
        desired_sharding_key.each do |_, details|
          referenced_table_name = details['backfill_via']['parent']['table']
          column_name = details['backfill_via']['parent']['foreign_key']
          if allowed_to_be_missing_foreign_key.include?("#{table_name}.#{column_name}")
            expect(has_foreign_key?(table_name, column_name)).to eq(false),
              "The column `#{table_name}.#{column_name}` has a foreign key so cannot be " \
              "allowed_to_be_missing_foreign_key. " \
              "If this is a foreign key referencing the specified table #{referenced_table_name} " \
              "then you must remove it from allowed_to_be_missing_foreign_key"
          else
            expect(has_foreign_key?(table_name, column_name, to_table_name: referenced_table_name)).to eq(true),
              "Missing a foreign key constraint for `#{table_name}.#{column_name}` " \
              "referencing #{referenced_table_name}. " \
              "All desired sharding keys must have a foreign key constraint"
          end
        end
      end
    end

    it 'belongs to parent association via a non-nullable column', :aggregate_failures do
      all_tables_to_desired_sharding_key.each do |table_name, desired_sharding_key|
        desired_sharding_key.each do |_, details|
          column_name = details['backfill_via']['parent']['foreign_key']

          not_nullable = not_nullable?(table_name, column_name)
          has_null_check_constraint = has_null_check_constraint?(table_name, column_name)

          if allowed_to_be_missing_not_null.include?("#{table_name}.#{column_name}")
            expect(not_nullable || has_null_check_constraint).to eq(false),
              "You must remove `#{table_name}.#{column_name}` from allowed_to_be_missing_not_null " \
              "since it now has a valid constraint."
          else
            expect(not_nullable || has_null_check_constraint).to eq(true),
              "Missing a not null constraint for `#{table_name}.#{column_name}` . " \
              "All desired sharding keys must be not nullable or have a NOT NULL check constraint"
          end
        end
      end
    end
  end

  context 'for tables that do not already have a backfilled, non-nullable sharding key on their parent' \
          'but only has a desired sharding key on their parent' do
    it 'the parent.belongs_to must be a model with a desired_sharding_key' do
      desired_sharding_key_entries_awaiting_backfill_on_parent.each do |entry|
        model = entry.classes.first.constantize
        entry.desired_sharding_key.each do |column, details|
          parent = details['backfill_via']['parent']
          parent_table = parent['table']
          belongs_to = parent['belongs_to']
          sharding_key_of_parent = parent['sharding_key']

          parent_association = model.reflect_on_association(belongs_to)
          expect(parent_association).not_to be_nil,
            "Invalid backfill_via.parent.belongs_to: #{belongs_to} in db/docs for #{entry.table_name}"

          expect(desired_sharding_keys_of(parent_table).keys).to include(column)
          expect(desired_sharding_keys_of(parent_table).keys).to include(sharding_key_of_parent)
        end
      end
    end
  end

  private

  def error_message_incorrect_reference(table_name, references)
    <<~HEREDOC
    The table `#{table_name}` has an invalid `desired_sharding_key` in the `db/docs` YML file. The column references `#{references}` but it must reference one of `#{allowed_sharding_key_referenced_tables.join(', ')}`.

      To choose an appropriate desired_sharding_key for this table please refer
      to our guidelines at https://docs.gitlab.com/ee/development/database/multiple_databases.html#defining-a-desired-sharding-key, or consult with the Tenant Scale group.
    HEREDOC
  end

  def all_tables_to_desired_sharding_key
    desired_sharding_key_entries_not_awaiting_backfill_on_parent.map do |entry|
      [entry.table_name, entry.desired_sharding_key]
    end
  end

  def desired_sharding_key_entries
    ::Gitlab::Database::Dictionary.entries.select do |entry|
      entry.desired_sharding_key.present?
    end
  end

  def desired_sharding_key_entries_not_awaiting_backfill_on_parent
    ::Gitlab::Database::Dictionary.entries.select do |entry|
      entry.desired_sharding_key.present? &&
        entry.desired_sharding_key.all? { |_, details| details['awaiting_backfill_on_parent'].blank? }
    end
  end

  def desired_sharding_key_entries_awaiting_backfill_on_parent
    ::Gitlab::Database::Dictionary.entries.select do |entry|
      entry.desired_sharding_key.present? &&
        entry.desired_sharding_key.all? { |_, details| details['awaiting_backfill_on_parent'] }
    end
  end

  def desired_sharding_keys_of(table_name)
    Gitlab::Database::Dictionary.entries.find_by_table_name(table_name).desired_sharding_key
  end
end
