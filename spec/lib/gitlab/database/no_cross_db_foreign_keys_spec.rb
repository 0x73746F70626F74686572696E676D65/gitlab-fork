# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'cross-database foreign keys' do
  # TODO: We are trying to empty out this list in
  # https://gitlab.com/groups/gitlab-org/-/epics/7249 . Once we are done we can
  # keep this test and assert that there are no cross-db foreign keys. We
  # should not be adding anything to this list but should instead only add new
  # loose foreign keys
  # https://docs.gitlab.com/ee/development/database/loose_foreign_keys.html .
  let(:allowed_cross_database_foreign_keys) do
    %w(
      ci_build_report_results.project_id
      ci_builds.project_id
      ci_builds_metadata.project_id
      ci_daily_build_group_report_results.group_id
      ci_daily_build_group_report_results.project_id
      ci_freeze_periods.project_id
      ci_job_artifacts.project_id
      ci_job_token_project_scope_links.added_by_id
      ci_job_token_project_scope_links.source_project_id
      ci_job_token_project_scope_links.target_project_id
      ci_pending_builds.namespace_id
      ci_pending_builds.project_id
      ci_pipeline_schedules.owner_id
      ci_pipeline_schedules.project_id
      ci_pipelines.merge_request_id
      ci_pipelines.project_id
      ci_project_monthly_usages.project_id
      ci_refs.project_id
      ci_resource_groups.project_id
      ci_runner_namespaces.namespace_id
      ci_runner_projects.project_id
      ci_running_builds.project_id
      ci_sources_pipelines.project_id
      ci_sources_pipelines.source_project_id
      ci_sources_projects.source_project_id
      ci_stages.project_id
      ci_subscriptions_projects.downstream_project_id
      ci_subscriptions_projects.upstream_project_id
      ci_triggers.owner_id
      ci_triggers.project_id
      ci_unit_tests.project_id
      ci_variables.project_id
      dast_profiles_pipelines.ci_pipeline_id
      dast_scanner_profiles_builds.ci_build_id
      dast_site_profiles_builds.ci_build_id
      dast_site_profiles_pipelines.ci_pipeline_id
      external_pull_requests.project_id
      merge_requests.head_pipeline_id
      merge_trains.pipeline_id
      requirements_management_test_reports.build_id
      security_scans.build_id
      vulnerability_feedback.pipeline_id
      vulnerability_occurrence_pipelines.pipeline_id
      vulnerability_statistics.latest_pipeline_id
    ).freeze
  end

  def foreign_keys_for(table_name)
    ApplicationRecord.connection.foreign_keys(table_name)
  end

  def is_cross_db?(fk_record)
    Gitlab::Database::GitlabSchema.table_schemas([fk_record.from_table, fk_record.to_table]).many?
  end

  it 'onlies have allowed list of cross-database foreign keys', :aggregate_failures do
    all_tables = ApplicationRecord.connection.data_sources

    all_tables.each do |table|
      foreign_keys_for(table).each do |fk|
        if is_cross_db?(fk)
          column = "#{fk.from_table}.#{fk.column}"
          expect(allowed_cross_database_foreign_keys).to include(column), "Found extra cross-database foreign key #{column} referencing #{fk.to_table} with constraint name #{fk.name}. When a foreign key references another database you must use a Loose Foreign Key instead https://docs.gitlab.com/ee/development/database/loose_foreign_keys.html ."
        end
      end
    end
  end
end
