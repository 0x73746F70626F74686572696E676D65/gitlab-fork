# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PipelineHelper do
  include Ci::BuildsHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:raw_pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }
  let_it_be(:pipeline) { Ci::PipelinePresenter.new(raw_pipeline, current_user: user)}

  describe '#js_pipeline_tabs_data' do
    subject(:pipeline_tabs_data) { helper.js_pipeline_tabs_data(project, pipeline) }

    it 'returns pipeline tabs data' do
      expect(pipeline_tabs_data).to eq({
        can_generate_codequality_reports: pipeline.can_generate_codequality_reports?.to_json,
        codequality_report_download_path: helper.codequality_report_download_path(project, pipeline),
        expose_license_scanning_data: pipeline.expose_license_scanning_data?.to_json,
        expose_security_dashboard: pipeline.expose_security_dashboard?.to_json,
        failed_jobs_count: pipeline.failed_builds.count,
        failed_jobs_summary: prepare_failed_jobs_summary_data(pipeline.failed_builds),
        full_path: project.full_path,
        graphql_resource_etag: graphql_etag_pipeline_path(pipeline),
        metrics_path: namespace_project_ci_prometheus_metrics_histograms_path(namespace_id: project.namespace, project_id: project, format: :json),
        pipeline_iid: pipeline.iid,
        pipeline_project_path: project.full_path,
        total_job_count: pipeline.total_size
      })
    end
  end

  describe 'codequality_report_download_path' do
    before do
      project.add_developer(user)
    end

    subject(:codequality_report_path) { helper.codequality_report_download_path(project, pipeline) }

    describe 'when `full_codequality_report` feature is not available' do
      before do
        stub_licensed_features(full_codequality_report: false)
      end

      it 'returns nil' do
        is_expected.to be(nil)
      end
    end

    describe 'when `full_code_quality_report` feature is available' do
      before do
        stub_licensed_features(full_codequality_report: true)
      end

      describe 'and there is no artefact for codequality' do
        it 'returns nil for `codequality`' do
          is_expected.to be(nil)
        end
      end

      describe 'and there is an artefact for codequality' do
        before do
          create(:ci_build, :codequality_report, pipeline: raw_pipeline)
        end

        it 'returns the downloadable path for `codequality`' do
          is_expected.not_to be(nil)
          is_expected.to eq(pipeline.downloadable_path_for_report_type(:codequality))
        end
      end
    end
  end

  describe 'vulnerability_report_data' do
    before do
      project.add_developer(user)
      allow(helper).to receive(:can?).and_return(true)
    end

    subject(:vulnerability_report_data) { helper.vulnerability_report_data(project, pipeline, user) }

    it "returns the vulnerability report's data" do
      expect(vulnerability_report_data).to match({
        empty_state_svg_path: match_asset_path('/assets/illustrations/security-dashboard-empty-state.svg'),
        pipeline_id: pipeline.id,
        pipeline_iid: pipeline.iid,
        project_id: project.id,
        source_branch: pipeline.source_ref,
        pipeline_jobs_path: "/api/v4/projects/#{project.id}/pipelines/#{pipeline.id}/jobs",
        vulnerabilities_endpoint: "/api/v4/projects/#{project.id}/vulnerability_findings?pipeline_id=#{pipeline.id}",
        vulnerability_exports_endpoint: "/api/v4/security/projects/#{project.id}/vulnerability_exports",
        empty_state_unauthorized_svg_path: match_asset_path('/assets/illustrations/user-not-logged-in.svg'),
        empty_state_forbidden_svg_path: match_asset_path('/assets/illustrations/lock_promotion.svg'),
        project_full_path: project.path_with_namespace,
        commit_path_template: "/#{project.path_with_namespace}/-/commit/$COMMIT_SHA",
        can_admin_vulnerability: 'true',
        can_view_false_positive: 'false'
      })
    end
  end
end
