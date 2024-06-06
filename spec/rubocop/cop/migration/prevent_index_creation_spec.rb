# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/migration/prevent_index_creation'

RSpec.describe RuboCop::Cop::Migration::PreventIndexCreation do
  let(:forbidden_tables) do
    %w[
      ci_builds
      namespaces
      projects
      users
      merge_requests
      merge_request_metrics
      merge_request_diffs
      merge_request_diff_commits
      notes
      web_hook_logs
      events
      project_statistics
      sent_notifications
      issues
      issue_search_data
      packages_packages
      vulnerability_occurrences
      sbom_occurrences
      security_findings
      deployments
    ].freeze
  end

  context 'when in migration' do
    before do
      allow(cop).to receive(:in_migration?).and_return(true)
    end

    let(:offense) { "Adding new index to certain tables is forbidden. [...]" }

    context 'when adding an index to a forbidden table' do
      it 'does not register an offense when direction is down' do
        forbidden_tables.each do |table_name|
          expect_no_offenses(<<~RUBY)
            def down
              add_concurrent_index :#{table_name}, :runners_token, unique: true, name: INDEX_NAME
            end
          RUBY
        end
      end

      context 'when table_name is a symbol' do
        it "registers an offense when add_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                add_index :#{table_name}, :protected
                ^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end

        it "registers an offense when add_concurrent_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                add_concurrent_index :#{table_name}, :protected
                ^^^^^^^^^^^^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end

        it "registers an offense when prepare_async_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                prepare_async_index :#{table_name}, :protected
                ^^^^^^^^^^^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end
      end

      context 'when table_name is a string' do
        it "registers an offense when add_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                add_index "#{table_name}", :protected
                ^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end

        it "registers an offense when add_concurrent_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                add_concurrent_index "#{table_name}", :protected
                ^^^^^^^^^^^^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end

        it "registers an offense when prepare_async_index is used", :aggregate_failures do
          forbidden_tables.each do |table_name|
            expect_offense(<<~RUBY)
              def change
                prepare_async_index "#{table_name}", :protected
                ^^^^^^^^^^^^^^^^^^^ #{offense}
              end
            RUBY
          end
        end
      end

      context 'when table_name is a constant' do
        it "registers an offense when add_concurrent_index is used", :aggregate_failures do
          expect_offense(<<~RUBY)
            INDEX_NAME = "index_name"
            TABLE_NAME = :ci_builds
            disable_ddl_transaction!

            def change
              add_concurrent_index TABLE_NAME, :protected
              ^^^^^^^^^^^^^^^^^^^^ #{offense}
            end
          RUBY
        end

        it "registers an offense when prepare_async_index is used", :aggregate_failures do
          expect_offense(<<~RUBY)
            INDEX_NAME = "index_name"
            TABLE_NAME = :ci_builds
            disable_ddl_transaction!

            def change
              prepare_async_index TABLE_NAME, :protected
              ^^^^^^^^^^^^^^^^^^^ #{offense}
            end
          RUBY
        end
      end
    end

    context 'when adding an index to a regular table' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          def change
            add_index :ci_pipelines, :locked
          end
        RUBY
      end

      context 'when using a constant' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            disable_ddl_transaction!

            TABLE_NAME = "not_forbidden"

            def up
              add_concurrent_index TABLE_NAME, :protected
            end
          RUBY
        end
      end
    end

    context 'when preparing an async index for a regular table' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          def change
            prepare_async_index :ci_pipelines, :locked
          end
        RUBY
      end

      context 'when using a constant' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            disable_ddl_transaction!

            TABLE_NAME = "not_forbidden"

            def up
              prepare_async_index TABLE_NAME, :protected
            end
          RUBY
        end
      end
    end
  end

  context 'when outside of migration' do
    it 'does not register an offense' do
      expect_no_offenses('def change; add_index :table, :column; end')
    end
  end
end
