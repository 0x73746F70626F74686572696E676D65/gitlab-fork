# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Pipeline, feature_category: :continuous_integration do
  include Ci::SourcePipelineHelpers
  using RSpec::Parameterized::TableSyntax

  let(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }

  let_it_be(:pipeline, refind: true) do
    create(:ci_empty_pipeline, status: :created, project: project)
  end

  describe 'associations' do
    it { is_expected.to have_many(:security_scans).class_name('Security::Scan') }
    it { is_expected.to have_many(:security_findings).through(:security_scans).class_name('Security::Finding').source(:findings) }
    it { is_expected.to have_many(:downstream_bridges) }
    it { is_expected.to have_many(:vulnerability_findings).through(:vulnerabilities_finding_pipelines).class_name('Vulnerabilities::Finding') }
    it { is_expected.to have_many(:vulnerabilities_finding_pipelines).class_name('Vulnerabilities::FindingPipeline') }
    it { is_expected.to have_one(:dast_profiles_pipeline).class_name('Dast::ProfilesPipeline').with_foreign_key(:ci_pipeline_id) }
    it { is_expected.to have_one(:dast_profile).class_name('Dast::Profile').through(:dast_profiles_pipeline) }
  end

  describe '.failure_reasons' do
    it 'contains failure reasons about exceeded limits' do
      expect(described_class.failure_reasons)
        .to include 'size_limit_exceeded'
    end
  end

  describe '.latest_completed_or_manual_pipeline_ids_per_source', feature_category: :security_policy_management do
    let_it_be(:push_pipeline_1) { create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:push], sha: 'sha') }
    let_it_be(:web_pipeline) { create(:ci_pipeline, :manual, project: project, source: Enums::Ci::Pipeline.sources[:web], sha: 'sha') }
    let_it_be(:merge_request_pipeline_1) { create(:ci_pipeline, :failed, project: project, source: Enums::Ci::Pipeline.sources[:merge_request_event], sha: 'sha') }
    let_it_be(:security_policy_pipeline) { create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:security_orchestration_policy], sha: 'sha') }

    let_it_be(:push_pipeline_2) { create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:push], sha: 'sha') }
    let_it_be(:merge_request_pipeline_2) { create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:merge_request_event], sha: 'sha') }
    let_it_be(:web_pipeline_with_different_sha) { create(:ci_pipeline, :success, project: project, source: Enums::Ci::Pipeline.sources[:web], sha: 'sha2') }

    it 'returns expected pipeline ids' do
      expect(described_class.latest_completed_or_manual_pipeline_ids_per_source('sha'))
        .to contain_exactly(web_pipeline, security_policy_pipeline, push_pipeline_2, merge_request_pipeline_2)
    end
  end

  describe '#batch_lookup_report_artifact_for_file_type' do
    shared_examples '#batch_lookup_report_artifact_for_file_type' do |file_type, license|
      context 'when feature is available' do
        before do
          stub_licensed_features("#{license}": true)
        end

        it "returns the #{file_type} artifact" do
          expect(pipeline.batch_lookup_report_artifact_for_file_type(file_type)).to eq(pipeline.job_artifacts.sample)
        end
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features("#{license}": false)
        end

        it "doesn't return the #{file_type} artifact" do
          expect(pipeline.batch_lookup_report_artifact_for_file_type(file_type)).to be_nil
        end
      end
    end

    context 'with security report artifact' do
      let_it_be(:pipeline, reload: true) { create(:ee_ci_pipeline, :with_dependency_scanning_report, project: project) }

      include_examples '#batch_lookup_report_artifact_for_file_type', :dependency_scanning, :dependency_scanning
    end

    context 'with license scanning artifact' do
      let_it_be(:pipeline, reload: true) { create(:ee_ci_pipeline, :with_license_scanning_report, project: project) }

      include_examples '#batch_lookup_report_artifact_for_file_type', :license_scanning, :license_scanning
    end

    context 'with browser performance artifact' do
      let_it_be(:pipeline, reload: true) { create(:ee_ci_pipeline, :with_browser_performance_report, project: project) }

      include_examples '#batch_lookup_report_artifact_for_file_type', :browser_performance, :merge_request_performance_metrics
    end

    context 'with load performance artifact' do
      let_it_be(:pipeline, reload: true) { create(:ee_ci_pipeline, :with_load_performance_report, project: project) }

      include_examples '#batch_lookup_report_artifact_for_file_type', :load_performance, :merge_request_performance_metrics
    end
  end

  describe '#security_reports' do
    subject { pipeline.security_reports }

    before do
      stub_licensed_features(sast: true, dependency_scanning: true, container_scanning: true, cluster_image_scanning: true)
    end

    context 'when pipeline has multiple builds with security reports' do
      let(:build_sast_1) { create(:ci_build, :success, name: 'sast_1', pipeline: pipeline, project: project) }
      let(:build_sast_2) { create(:ci_build, :success, name: 'sast_2', pipeline: pipeline, project: project) }
      let(:build_ds_1) { create(:ci_build, :success, name: 'ds_1', pipeline: pipeline, project: project) }
      let(:build_ds_2) { create(:ci_build, :success, name: 'ds_2', pipeline: pipeline, project: project) }
      let(:build_cs_1) { create(:ci_build, :success, name: 'cs_1', pipeline: pipeline, project: project) }
      let(:build_cs_2) { create(:ci_build, :success, name: 'cs_2', pipeline: pipeline, project: project) }
      let(:build_cis_1) { create(:ci_build, :success, name: 'cis_1', pipeline: pipeline, project: project) }
      let(:build_cis_2) { create(:ci_build, :success, name: 'cis_2', pipeline: pipeline, project: project) }
      let!(:sast1_artifact) { create(:ee_ci_job_artifact, :sast, job: build_sast_1, project: project) }
      let!(:sast2_artifact) { create(:ee_ci_job_artifact, :sast, job: build_sast_2, project: project) }
      let!(:ds1_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: build_ds_1, project: project) }
      let!(:ds2_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: build_ds_2, project: project) }
      let!(:cs1_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: build_cs_1, project: project) }
      let!(:cs2_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: build_cs_2, project: project) }
      let!(:cis1_artifact) { create(:ee_ci_job_artifact, :cluster_image_scanning, job: build_cis_1, project: project) }
      let!(:cis2_artifact) { create(:ee_ci_job_artifact, :cluster_image_scanning, job: build_cis_2, project: project) }

      it 'assigns pipeline to the reports' do
        expect(subject.pipeline).to eq(pipeline)
        expect(subject.reports.values.map(&:pipeline).uniq).to contain_exactly(pipeline)
      end

      it 'returns security reports with collected data grouped as expected' do
        expect(subject.reports.keys).to contain_exactly('sast', 'dependency_scanning', 'container_scanning', 'cluster_image_scanning')

        # for each of report categories, we have merged 2 reports with the same data (fixture)
        expect(subject.get_report('sast', sast1_artifact).findings.size).to eq(5)
        expect(subject.get_report('dependency_scanning', ds1_artifact).findings.size).to eq(4)
        expect(subject.get_report('container_scanning', cs1_artifact).findings.size).to eq(8)
        expect(subject.get_report('cluster_image_scanning', cis1_artifact).findings.size).to eq(2)
      end

      context 'when builds are retried' do
        let(:build_sast_1) { create(:ci_build, :retried, name: 'sast_1', pipeline: pipeline, project: project) }

        it 'does not take retried builds into account' do
          expect(subject.get_report('sast', sast1_artifact).findings.size).to eq(5)
          expect(subject.get_report('dependency_scanning', ds1_artifact).findings.size).to eq(4)
          expect(subject.get_report('container_scanning', cs1_artifact).findings.size).to eq(8)
          expect(subject.get_report('cluster_image_scanning', cis1_artifact).findings.size).to eq(2)
        end
      end

      context 'when the `report_types` parameter is provided' do
        subject(:filtered_report_types) { pipeline.security_reports(report_types: %w[sast]).reports.values.map(&:type).uniq }

        it 'returns only the reports which are requested' do
          expect(filtered_report_types).to eq(%w[sast])
        end
      end

      context 'when pipeline is a child pipeline' do
        let_it_be(:parent_pipeline) { create(:ci_empty_pipeline, project: project) }
        let_it_be(:pipeline) do
          create(:ci_empty_pipeline, child_of: parent_pipeline, status: :created, project: project)
        end

        let(:parent_reports) { parent_pipeline.security_reports.reports }

        it 'the reports should be accessible from the parent pipeline', :aggregate_failures do
          expect(parent_reports.keys).to contain_exactly(*subject.reports.keys)
          expect(parent_reports).not_to be_empty
        end
      end
    end

    context 'when pipeline does not have any builds with security reports' do
      it 'returns empty security reports' do
        expect(subject.reports).to eq({})
      end
    end
  end

  describe '::Security::StoreScansWorker' do
    shared_examples_for 'storing the security scans' do |transition|
      subject(:transition_pipeline) { pipeline.update!(status_event: transition) }

      before do
        allow(::Security::StoreScansWorker).to receive(:perform_async)
        allow(pipeline).to receive(:can_store_security_reports?).and_return(can_store_security_reports)
      end

      context 'when the security scans can be stored for the pipeline' do
        let(:can_store_security_reports) { true }

        it 'schedules store security scans job' do
          transition_pipeline

          expect(::Security::StoreScansWorker).to have_received(:perform_async).with(pipeline.id)
        end
      end

      context 'when the security scans can not be stored for the pipeline' do
        let(:can_store_security_reports) { false }

        it 'does not schedule store security scans job' do
          transition_pipeline

          expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
        end
      end
    end

    shared_examples_for 'completed statuses scans are stored' do
      context 'when pipeline is succeeded' do
        it_behaves_like 'storing the security scans', :succeed
      end

      context 'when pipeline is dropped' do
        it_behaves_like 'storing the security scans', :drop
      end

      context 'when pipeline is skipped' do
        it_behaves_like 'storing the security scans', :skip
      end

      context 'when pipeline is canceled' do
        it_behaves_like 'storing the security scans', :cancel
      end
    end

    it_behaves_like 'completed statuses scans are stored'

    context 'when pipeline is blocked' do
      it_behaves_like 'storing the security scans', :block
    end

    context 'when include_manual_to_pipeline_completion is false' do
      before do
        stub_feature_flags(include_manual_to_pipeline_completion: false)
      end

      it_behaves_like 'completed statuses scans are stored'

      context 'when pipeline is blocked' do
        it 'does not schedule store security scans job' do
          allow(::Security::StoreScansWorker).to receive(:perform_async)

          pipeline.update!(status_event: :block)

          expect(::Security::StoreScansWorker).not_to have_received(:perform_async)
        end
      end
    end
  end

  describe '::Ai::StoreRepositoryXrayWorker' do
    shared_examples_for 'storing the xray reports' do |transition|
      subject(:transition_pipeline) { pipeline.update!(status_event: transition) }

      before do
        allow(pipeline).to receive(:has_repository_xray_reports?).and_return(has_repository_xray_reports)
      end

      context 'when the xray reports can be stored for the pipeline' do
        let(:has_repository_xray_reports) { true }

        it 'schedules store security scans job' do
          expect(::Ai::StoreRepositoryXrayWorker).to receive(:perform_async).with(pipeline.id)

          transition_pipeline
        end
      end

      context 'when the xray reports can not be stored for the pipeline' do
        let(:has_repository_xray_reports) { false }

        it 'does not schedule store security scans job' do
          expect(::Ai::StoreRepositoryXrayWorker).not_to receive(:perform_async)

          transition_pipeline
        end
      end
    end

    context 'when pipeline is succeeded' do
      it_behaves_like 'storing the xray reports', :succeed
    end

    context 'when pipeline is dropped' do
      it_behaves_like 'storing the xray reports', :drop
    end

    context 'when pipeline is skipped' do
      it_behaves_like 'storing the xray reports', :skip
    end

    context 'when pipeline is canceled' do
      it_behaves_like 'storing the xray reports', :cancel
    end
  end

  describe '::Security::UnenforceablePolicyRulesPipelineNotificationWorker' do
    shared_examples_for 'notification for unenforceable policy rules' do |transition|
      subject(:transition_pipeline) { pipeline.update!(status_event: transition) }

      before do
        allow(::Security::UnenforceablePolicyRulesPipelineNotificationWorker).to receive(:perform_async)
      end

      it 'schedules notification job for unenforceable policies' do
        transition_pipeline

        expect(::Security::UnenforceablePolicyRulesPipelineNotificationWorker).to have_received(:perform_async).with(pipeline.id)
      end
    end

    context 'when pipeline is succeeded' do
      it_behaves_like 'notification for unenforceable policy rules', :succeed
    end

    context 'when pipeline is dropped' do
      it_behaves_like 'notification for unenforceable policy rules', :drop
    end

    context 'when pipeline is skipped' do
      it_behaves_like 'notification for unenforceable policy rules', :skip
    end

    context 'when pipeline is canceled' do
      it_behaves_like 'notification for unenforceable policy rules', :cancel
    end
  end

  describe 'Sbom Ingestion' do
    let(:sbom_ingestion_scheduler) { instance_double(::Sbom::ScheduleIngestReportsService, execute: nil) }

    subject(:transition_pipeline) { pipeline.update!(status_event: transition) }

    before do
      allow(::Sbom::ScheduleIngestReportsService).to receive(:new).with(pipeline).and_return(sbom_ingestion_scheduler)
    end

    shared_examples_for 'ingesting sbom reports' do
      context 'when security reports are available' do
        before do
          allow(pipeline).to receive(:can_store_security_reports?).and_return(true)
        end

        it 'does not try to ingest the SBOM reports' do
          transition_pipeline

          expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
        end
      end

      context 'when security reports are not available' do
        before do
          allow(pipeline).to receive(:can_store_security_reports?).and_return(false)
        end

        it 'tries to ingest sbom reports' do
          transition_pipeline

          expect(::Sbom::ScheduleIngestReportsService).to have_received(:new).with(pipeline)
          expect(sbom_ingestion_scheduler).to have_received(:execute)
        end
      end
    end

    context 'when transitioning to completed or blocked status' do
      where(:transition) { %i[succeed drop skip cancel block] }

      with_them do
        it_behaves_like 'ingesting sbom reports'
      end

      context 'with include_manual_to_pipeline_completion FF disabled' do
        before do
          stub_feature_flags(include_manual_to_pipeline_completion: false)
        end

        context 'for completed status' do
          where(:transition) { %i[succeed drop skip cancel] }

          with_them do
            it_behaves_like 'ingesting sbom reports'
          end
        end

        context 'for manual status' do
          where(:transition) do
            %i[
              block
            ]
          end

          with_them do
            it 'does not try to ingest sbom reports' do
              transition_pipeline

              expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
            end
          end
        end
      end
    end

    context 'when transitioning to a non-completed status except block' do
      where(:transition) do
        %i[
          enqueue
          request_resource
          prepare
          run
          delay
        ]
      end

      with_them do
        it 'does not try to ingest sbom reports' do
          transition_pipeline

          expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
        end
      end

      context 'with include_manual_to_pipeline_completion FF disabled' do
        before do
          stub_feature_flags(include_manual_to_pipeline_completion: false)
        end

        where(:transition) do
          %i[
            enqueue
            request_resource
            prepare
            block
            run
            delay
          ]
        end

        with_them do
          it 'does not try to ingest sbom reports' do
            transition_pipeline

            expect(::Sbom::ScheduleIngestReportsService).not_to have_received(:new)
          end
        end
      end
    end
  end

  describe '#dependency_list_reports', feature_category: :dependency_management do
    subject { pipeline.dependency_list_report }

    before do
      stub_licensed_features(dependency_scanning: true, license_scanning: true)
    end

    context 'when pipeline has a build with dependency list reports' do
      let_it_be(:build) { create(:ee_ci_build, :success, :dependency_list, pipeline: pipeline, project: project) }
      let_it_be(:build1) { create(:ee_ci_build, :success, :dependency_scanning, pipeline: pipeline, project: project) }
      let_it_be(:build2) { create(:ee_ci_build, :success, :cyclonedx, pipeline: pipeline, project: project) }

      it 'returns a dependency list report with collected data' do
        mini_portile2 = subject.dependencies.find { |x| x[:name] == 'mini_portile2' }

        expect(subject.dependencies.count).to eq(21)
        expect(mini_portile2[:name]).not_to be_empty
        expect(mini_portile2[:licenses]).to be_empty
      end

      context 'when builds are retried' do
        before do
          build.update!(retried: true)
          build1.update!(retried: true)
        end

        it 'does not take retried builds into account' do
          expect(subject.dependencies).to be_empty
        end
      end

      context 'with failed builds' do
        it 'does not runs queries on failed builds' do
          control = ActiveRecord::QueryRecorder.new { subject }

          create(:ee_ci_build, :failed, :dependency_scanning, pipeline: pipeline, project: project)
          create(:ee_ci_build, :failed, :license_scanning, pipeline: pipeline, project: project)

          expect { subject }.not_to exceed_query_limit(control)
        end
      end
    end

    context 'when pipeline does not have any builds with dependency_list reports' do
      it 'returns an empty dependency_list report' do
        expect(subject.dependencies).to be_empty
      end
    end
  end

  describe '#metrics_report' do
    subject { pipeline.metrics_report }

    before do
      stub_licensed_features(metrics_reports: true)
    end

    context 'when pipeline has multiple builds with metrics reports' do
      before do
        create(:ee_ci_build, :success, :metrics, pipeline: pipeline, project: project)
      end

      it 'returns a metrics report with collected data' do
        expect(subject.metrics.count).to eq(2)
      end
    end

    context 'when pipeline has multiple builds with metrics reports that are retried' do
      before do
        create_list(:ee_ci_build, 2, :retried, :success, :metrics, pipeline: pipeline, project: project)
      end

      it 'does not take retried builds into account' do
        expect(subject.metrics).to be_empty
      end
    end

    context 'when pipeline does not have any builds with metrics reports' do
      it 'returns an empty metrics report' do
        expect(subject.metrics).to be_empty
      end
    end
  end

  describe '#sbom_reports' do
    subject { pipeline.sbom_reports }

    context 'when pipeline has a build with sbom reports' do
      it 'returns a list of sbom reports belonging to the artifact' do
        create(:ee_ci_build, :success, :cyclonedx, pipeline: pipeline, project: project)

        expect(subject.reports.count).to eq(4)
      end
    end

    context 'when pipeline has multiple builds with sbom reports' do
      it 'returns a list of sbom reports belonging to the artifact' do
        create(:ee_ci_build, :success, :cyclonedx, pipeline: pipeline, project: project)
        create(:ee_ci_build, :success, :cyclonedx, pipeline: pipeline, project: project)

        expect(subject.reports.count).to eq(8)
      end
    end

    context 'when pipeline does not have any builds with sbom reports' do
      it 'returns an empty reports list' do
        expect(subject.reports).to be_empty
      end
    end

    context 'when pipeline has children with sbom reports' do
      let_it_be(:child_pipeline) do
        create(:ci_empty_pipeline, child_of: pipeline, status: :created, project: project)
      end

      let_it_be(:build_sbom) { create(:ee_ci_build, :success, :cyclonedx, pipeline: child_pipeline, project: project) }

      subject { pipeline.sbom_reports(self_and_project_descendants: true) }

      it 'the sbom should be accessible from the pipeline', :aggregate_failures do
        expect(subject.reports.count).to eq(4)
      end
    end
  end

  describe 'state machine transitions' do
    context 'Ci::SyncReportsToReportApprovalRulesWorker' do
      let(:pipeline) { create(:ci_empty_pipeline, status: from_status) }

      shared_examples 'schedules worker' do
        Ci::HasStatus::ACTIVE_STATUSES.each do |status|
          context "from #{status}" do
            let(:from_status) { status }

            it do
              expect(Ci::SyncReportsToReportApprovalRulesWorker).to receive(:perform_async).with(pipeline.id)

              transition_pipeline
            end
          end
        end
      end

      context 'on pipeline complete' do
        subject(:transition_pipeline) { pipeline.succeed }

        it_behaves_like 'schedules worker'
      end

      context 'on pipeline manual' do
        subject(:transition_pipeline) { pipeline.block }

        it_behaves_like 'schedules worker'
      end

      context 'when include_manual_to_pipeline_completion is disabled' do
        before do
          stub_feature_flags(include_manual_to_pipeline_completion: false)
        end

        context 'on pipeline complete' do
          subject(:transition_pipeline) { pipeline.succeed }

          it_behaves_like 'schedules worker'
        end

        context 'on pipeline manual' do
          subject(:transition_pipeline) { pipeline.block }

          Ci::HasStatus::ACTIVE_STATUSES.each do |status|
            context "from #{status}" do
              let(:from_status) { status }

              it 'does not schedule worker' do
                expect(Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)

                transition_pipeline
              end
            end
          end
        end
      end
    end

    context 'when pipeline has downstream bridges' do
      before do
        pipeline.downstream_bridges << create(:ci_bridge)
      end

      context "when transitioning to success" do
        it 'schedules the pipeline bridge worker' do
          expect(::Ci::PipelineBridgeStatusWorker).to receive(:perform_async).with(pipeline.id)

          pipeline.succeed!
        end
      end

      context 'when transitioning to blocked' do
        it 'schedules the pipeline bridge worker' do
          expect(::Ci::PipelineBridgeStatusWorker).to receive(:perform_async).with(pipeline.id)

          pipeline.block!
        end
      end
    end

    context 'when pipeline project has downstream subscriptions' do
      let(:downstream_project) { create(:project) }
      let(:project) { create(:project, :public) }
      let(:pipeline) { create(:ci_empty_pipeline, project: project) }

      context 'when pipeline runs on a tag' do
        before do
          create(:ci_subscriptions_project, downstream_project: downstream_project, upstream_project: project)
          pipeline.update!(tag: true)
        end

        context 'when feature is not available' do
          before do
            stub_licensed_features(ci_project_subscriptions: false)
          end

          it 'does not schedule the trigger downstream subscriptions worker' do
            expect(::Ci::TriggerDownstreamSubscriptionsWorker).not_to receive(:perform_async)

            pipeline.succeed!
          end
        end

        context 'when feature is available' do
          before do
            stub_licensed_features(ci_project_subscriptions: true)
          end

          it 'schedules the trigger downstream subscriptions worker' do
            expect(::Ci::TriggerDownstreamSubscriptionsWorker).to receive(:perform_async)

            pipeline.succeed!
          end
        end
      end
    end
  end

  describe '#latest_merged_result_pipeline?' do
    subject { pipeline.latest_merged_result_pipeline? }

    let(:merge_request) { create(:merge_request, :with_merge_request_pipeline) }
    let(:pipeline) { merge_request.all_pipelines.first }
    let(:args) { {} }

    it { is_expected.to be_truthy }

    context 'when pipeline is not merge request pipeline' do
      let(:pipeline) { build(:ci_pipeline) }

      it { is_expected.to be_falsy }
    end

    context 'when source sha is outdated' do
      before do
        pipeline.source_sha = merge_request.diff_base_sha
      end

      it { is_expected.to be_falsy }
    end

    context 'when target sha is outdated' do
      before do
        pipeline.target_sha = 'old-sha'
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#retryable?' do
    subject { pipeline.retryable? }

    let(:pipeline) { merge_request.all_pipelines.last }
    let!(:build) { create(:ci_build, :canceled, pipeline: pipeline) }

    context 'with pipeline for merged results' do
      let(:merge_request) { create(:merge_request, :with_merge_request_pipeline) }

      it { is_expected.to be true }
    end

    context 'with running merge train pipeline' do
      let(:merge_request) { create(:merge_request, :with_pending_merge_train_pipeline) }

      it { is_expected.to be true }
    end

    context 'with merge train pipeline' do
      let(:merge_request) { create(:merge_request, :with_failed_merge_train_pipeline) }

      it { is_expected.to be false }
    end
  end

  describe '#merge_train_pipeline?' do
    subject { pipeline.merge_train_pipeline? }

    let!(:pipeline) do
      create(:ci_pipeline, source: :merge_request_event, merge_request: merge_request, ref: ref, target_sha: 'xxx')
    end

    let(:merge_request) { create(:merge_request) }
    let(:ref) { 'refs/merge-requests/1/train' }

    it { is_expected.to be_truthy }

    context 'when ref is merge ref' do
      let(:ref) { 'refs/merge-requests/1/merge' }

      it { is_expected.to be_falsy }
    end
  end

  describe '#merge_request_event_type' do
    subject { pipeline.merge_request_event_type }

    let(:pipeline) { merge_request.all_pipelines.last }

    context 'when pipeline is merge train pipeline' do
      let(:merge_request) { create(:merge_request, :with_pending_merge_train_pipeline) }

      it { is_expected.to eq(:merge_train) }
    end

    context 'when pipeline is merge request pipeline' do
      let(:merge_request) { create(:merge_request, :with_merge_request_pipeline) }

      it { is_expected.to eq(:merged_result) }
    end

    context 'when pipeline is detached merge request pipeline' do
      let(:merge_request) { create(:merge_request, :with_detached_merge_request_pipeline) }

      it { is_expected.to eq(:detached) }
    end
  end

  describe '#latest_failed_security_builds' do
    let(:sast_build) { create(:ee_ci_build, :sast, :failed, pipeline: pipeline) }
    let(:dast_build) { create(:ee_ci_build, :sast, pipeline: pipeline) }
    let(:retried_sast_build) { create(:ee_ci_build, :sast, :failed, :retried, pipeline: pipeline) }
    let(:expected_builds) { [sast_build] }

    before do
      allow_next_instance_of(::Security::SecurityJobsFinder) do |finder|
        allow(finder).to receive(:execute).and_return([sast_build, dast_build, retried_sast_build])
      end
    end

    subject { pipeline.latest_failed_security_builds }

    it { is_expected.to match_array(expected_builds) }
  end

  describe "#license_scan_completed?" do
    where(:pipeline_status, :build_types, :expected_status) do
      [
        [:blocked, [:container_scanning], false],
        [:blocked, [:cluster_image_scanning], false],
        [:blocked, [:license_scan_v2_1, :container_scanning], true],
        [:blocked, [:license_scan_v2_1], true],
        [:blocked, [], false],
        [:failed, [:container_scanning], false],
        [:failed, [:cluster_image_scanning], false],
        [:failed, [:license_scan_v2_1, :container_scanning], true],
        [:failed, [:license_scan_v2_1], true],
        [:failed, [], false],
        [:running, [:container_scanning], false],
        [:running, [:cluster_image_scanning], false],
        [:running, [:license_scan_v2_1, :container_scanning], true],
        [:running, [:license_scan_v2_1], true],
        [:running, [], false],
        [:success, [:container_scanning], false],
        [:success, [:cluster_image_scanning], false],
        [:success, [:license_scan_v2_1, :container_scanning], true],
        [:success, [:license_scan_v2_1], true],
        [:success, [], false]
      ]
    end

    with_them do
      subject { pipeline.license_scan_completed? }

      let(:pipeline) { create(:ci_pipeline, pipeline_status, builds: builds) }
      let(:builds) { build_types.map { |build_type| create(:ee_ci_build, build_type) } }

      specify { expect(subject).to eq(expected_status) }
    end
  end

  describe '#can_store_security_reports?', feature_category: :vulnerability_management do
    subject { pipeline.can_store_security_reports? }

    let(:pipeline) { create(:ci_empty_pipeline, status: :created, project: project) }

    before do
      pipeline.succeed!
    end

    context 'when the security reports can not be stored for the project' do
      before do
        allow(project).to receive(:can_store_security_reports?).and_return(false)
      end

      context 'when the pipeline does not have security reports' do
        it { is_expected.to be_falsy }
      end

      context 'when the pipeline has security reports' do
        before do
          create(:ee_ci_build, :sast, pipeline: pipeline, project: project)
        end

        it { is_expected.to be_falsy }
      end
    end

    context 'when the security reports can be stored for the project' do
      before do
        allow(project).to receive(:can_store_security_reports?).and_return(true)
      end

      context 'when the pipeline does not have security reports' do
        it { is_expected.to be_falsy }
      end

      context 'when the pipeline has security reports' do
        before do
          stage = create(:ci_stage)
          create(:ee_ci_build, :sast, pipeline: pipeline, project: project, ci_stage: stage)
        end

        it { is_expected.to be_truthy }

        context 'when the pipeline is blocked by manual jobs' do
          before do
            pipeline.block!
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#has_repository_xray_reports?', feature_category: :code_suggestions do
    subject { pipeline.has_repository_xray_reports? }

    let(:pipeline) { create(:ci_empty_pipeline, status: :created, project: project) }

    before do
      pipeline.succeed!
    end

    context 'when the pipeline does not have xray reports' do
      it { is_expected.to be_falsy }
    end

    context 'when the pipeline has xray reports' do
      before do
        create(:ee_ci_build, :repository_xray, pipeline: pipeline, project: project)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#can_ingest_sbom_reports?' do
    let(:ingest_sbom_reports_available) { true }

    subject { pipeline.can_ingest_sbom_reports? }

    before do
      allow(project.namespace).to receive(:ingest_sbom_reports_available?).and_return(ingest_sbom_reports_available)
    end

    context 'when pipeline has sbom_reports' do
      let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

      context 'when sbom report ingestion is available' do
        it { is_expected.to be true }
      end

      context 'when sbom report ingestion is not available' do
        let(:ingest_sbom_reports_available) { false }

        it { is_expected.to be false }
      end
    end

    context 'when pipeline does not have sbom_reports' do
      context 'when sbom report ingestion is available' do
        it { is_expected.to be false }
      end

      context 'when sbom report ingestion is not available' do
        let(:ingest_sbom_reports_available) { false }

        it { is_expected.to be false }
      end
    end
  end

  describe '#opened_merge_requests_with_head_sha' do
    let_it_be(:non_head_sha) { OpenSSL::Digest.hexdigest('SHA256', 'foo') }
    let_it_be(:merge_request) do
      create(:merge_request, :opened, source_project: project, source_branch: 'feature', target_branch: 'master')
    end

    let!(:other_merge_request) do
      create(:merge_request, :opened, source_project: project, source_branch: 'feature', target_branch: 'merge-test')
    end

    let!(:closed_merge_request) do
      create(:merge_request, :closed, source_project: project, source_branch: 'feature', target_branch: 'merged-target')
    end

    before do
      create(:merge_request_diff_commit,
        merge_request_diff: merge_request.merge_request_diff,
        sha: non_head_sha,
        relative_order: 5
      )
    end

    subject(:opened_merge_requests_with_head_sha) { pipeline.opened_merge_requests_with_head_sha }

    context 'when the pipeline ran for head_sha' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature', sha: merge_request.diff_head_sha) }

      it { is_expected.to contain_exactly(merge_request, other_merge_request) }
    end

    context 'when the pipeline did not run for head_sha' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature', sha: non_head_sha) }

      it { is_expected.to be_empty }
    end
  end

  describe '#has_all_security_policies_reports?', feature_category: :security_policy_management do
    subject { pipeline.has_all_security_policies_reports? }

    let(:pipeline) { build(:ci_empty_pipeline, status: :created, project: project) }

    before do
      allow(pipeline).to receive(:can_store_security_reports?).and_return(can_store_security_reports)
      allow(pipeline).to receive(:can_ingest_sbom_reports?).and_return(can_ingest_sbom_reports)
    end

    where(:can_store_security_reports, :can_ingest_sbom_reports, :result) do
      [
        [true, true, true],
        [true, false, false],
        [false, true, false],
        [false, false, false]
      ]
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#security_findings_partition_number' do
    let(:active_partition_number) { 555 }

    subject { pipeline.security_findings_partition_number }

    before do
      allow(Security::Finding).to receive(:active_partition_number).and_return(active_partition_number)
    end

    context 'when the pipeline already has associated `security_scans`' do
      let(:scans_partition_number) { 20 }

      before do
        create(:security_scan, findings_partition_number: scans_partition_number, pipeline: pipeline)
      end

      it { is_expected.to eq(scans_partition_number) }
    end

    context 'when the pipeline does not have associated `security_scans`' do
      it { is_expected.to eq(active_partition_number) }
    end
  end

  describe '#has_security_findings?' do
    subject { pipeline.has_security_findings? }

    context 'when the pipeline has security_findings' do
      before do
        scan = create(:security_scan, pipeline: pipeline)
        create(:security_finding, scan: scan)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the pipeline does not have security_findings' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#has_security_findings_in_self_and_descendants?' do
    subject { pipeline.has_security_findings_in_self_and_descendants? }

    let_it_be(:child_pipeline) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

    before do
      create_source_pipeline(pipeline, child_pipeline)
    end

    context 'when a child_pipeline has security_findings' do
      before do
        create(:security_finding,
          scan: create(:security_scan, status: :succeeded, project: project, pipeline: child_pipeline)
        )
      end

      it { is_expected.to be_truthy }
    end

    context 'when a child_pipeline does not have security_findings' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#triggered_for_ondemand_dast_scan?' do
    let(:pipeline_params) { { source: :ondemand_dast_scan, config_source: :parameter_source } }
    let(:pipeline) { build(:ci_pipeline, pipeline_params) }

    subject { pipeline.triggered_for_ondemand_dast_scan? }

    context 'when the feature flag is enabled' do
      it { is_expected.to be_truthy }

      context 'when the pipeline only has the correct source' do
        let(:pipeline_params) { { source: :ondemand_dast_scan } }

        it { is_expected.to be_falsey }
      end

      context 'when the pipeline only has the correct config_source' do
        let(:pipeline_params) { { config_source: :parameter_source } }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#needs_touch?' do
    subject { pipeline.needs_touch? }

    context 'when pipeline was updated less than 5 minutes ago' do
      before do
        pipeline.updated_at = 4.minutes.ago
      end

      it { is_expected.to eq(false) }
    end

    context 'when pipeline was updated more than 5 minutes ago' do
      before do
        pipeline.updated_at = 6.minutes.ago
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#vulnerability_findings' do
    subject(:vulnerability_findings) { pipeline.vulnerability_findings }

    let_it_be(:other_pipeline) { create(:ci_pipeline) }
    let_it_be(:initial_pipeline_finding) do
      create(
        :vulnerabilities_finding,
        pipeline: pipeline,
        latest_pipeline_id: other_pipeline.id
      ).tap { |finding| create(:vulnerabilities_finding_pipeline, finding: finding, pipeline: other_pipeline) }
    end

    let_it_be(:latest_pipeline_finding) do
      create(
        :vulnerabilities_finding,
        pipeline: other_pipeline,
        latest_pipeline_id: pipeline.id
      ).tap { |finding| create(:vulnerabilities_finding_pipeline, finding: finding, pipeline: pipeline) }
    end

    # When the FF is on, we simulate having dropped the table by
    # raising an exception
    it 'raises an exception when the FF is on' do
      expect { vulnerability_findings }.to raise_error NotImplementedError
    end

    context 'with deprecate_vulnerability_occurrence_pipelines FF disabled' do
      let(:expected_findings) { [initial_pipeline_finding, latest_pipeline_finding] }

      before do
        stub_feature_flags(deprecate_vulnerability_occurrence_pipelines: false)
      end

      it { is_expected.to match_array expected_findings }
    end
  end

  describe '#has_security_report_ingestion_warnings?' do
    subject { pipeline.has_security_report_ingestion_warnings? }

    context 'when there are no associated security scans with warnings' do
      it { is_expected.to be_falsey }
    end

    context 'when there is an associated security scan with warnings' do
      before do
        create(:security_scan, :with_warning, pipeline: pipeline)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#has_security_report_ingestion_errors?' do
    subject { pipeline.has_security_report_ingestion_errors? }

    context 'when there are no associated security scans with errors' do
      it { is_expected.to be_falsey }
    end

    context 'when there is an associated security scan with errors' do
      before do
        create(:security_scan, :with_error, pipeline: pipeline)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#total_ci_minutes_consumed', feature_category: :hosted_runners do
    let(:pipeline_consumption) do
      instance_double(::Gitlab::Ci::Minutes::PipelineConsumption, amount: 26)
    end

    before do
      allow(::Gitlab::Ci::Minutes::PipelineConsumption)
        .to receive(:new)
        .with(pipeline)
        .and_return(pipeline_consumption)
    end

    it "returns calculated ci_minutes" do
      expect(pipeline.total_ci_minutes_consumed).to eq(26)
    end
  end

  describe '#security_scan_types' do
    before do
      create(:security_scan, pipeline: pipeline, scan_type: scan_type)
    end

    let(:scan_type) { 'dast' }

    it 'returns security_scan_types' do
      expect(pipeline.security_scan_types).to match_array([scan_type])
    end
  end

  describe ".self_and_descendant_security_scans" do
    it 'returns the security scan from the parent and each child pipeline' do
      parent_pipeline = create(:ee_ci_pipeline, :success, project: project)
      pipeline_1 = create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project)
      pipeline_2 = create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project)
      parent_scan = create(:security_scan, pipeline: parent_pipeline)
      scan_1 = create(:security_scan, pipeline: pipeline_1)
      scan_2 = create(:security_scan, pipeline: pipeline_2)

      expect(parent_pipeline.self_and_descendant_security_scans).to match_array([parent_scan, scan_1, scan_2])
    end
  end

  describe "#merge_requests_as_base_pipeline" do
    let_it_be_with_reload(:pipeline) { create(:ci_empty_pipeline, project: project, status: 'created', ref: 'master', sha: 'a288a022a53a5a944fae87bcec6efc87b7061808') }
    let(:merge_request) { create(:merge_request, source_project: project) }
    let(:base_pipeline) { create(:ee_ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: merge_request.diff_base_sha) }
    let(:head_pipeline) { create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch) }

    it "returns merge requests whose `diff_base_sha` matches the pipeline's SHA" do
      project.reload
      expect(base_pipeline.merge_requests_as_base_pipeline).to eq([merge_request])
    end

    it "doesn't return merge requests whose `diff_base_sha` doesn't match the pipeline's SHA" do
      expect(head_pipeline.merge_requests_as_base_pipeline).to be_empty
    end
  end
end
