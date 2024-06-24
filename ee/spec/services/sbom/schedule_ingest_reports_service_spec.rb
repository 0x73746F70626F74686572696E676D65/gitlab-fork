# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ScheduleIngestReportsService, feature_category: :dependency_management do
  subject(:execute) { described_class.new(pipeline).execute }

  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let(:default_branch) { true }
    let(:ingest_sbom_reports_available) { true }

    context 'with a single pipeline' do
      shared_examples_for 'ingesting sbom reports in a single pipeline' do
        context 'when the project does NOT have SBOM ingestion available' do
          let(:ingest_sbom_reports_available) { false }

          it 'does not schedule Sbom::IngestReportsWorker' do
            execute

            expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
          end
        end

        context 'when the project has SBOM ingestion available' do
          let(:ingest_sbom_reports_available) { true }

          context 'on a non-default branch' do
            let(:default_branch) { false }

            it 'does not schedule Sbom::IngestReportsWorker' do
              execute

              expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
            end
          end

          context 'on the default branch' do
            context 'when there is no SBOM report' do
              it 'does not schedule Sbom::IngestReportsWorker' do
                execute

                expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
              end
            end

            context 'when there is an SBOM report' do
              let(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

              it 'schedules Sbom::IngestReportsWorker' do
                execute

                expect(Sbom::IngestReportsWorker).to have_received(:perform_async).with(pipeline.root_ancestor.id)
              end
            end
          end
        end
      end

      let_it_be(:pipeline) { create(:ee_ci_pipeline, :success, project: project) }

      before do
        allow(pipeline).to receive(:default_branch?).and_return(default_branch)
        allow(pipeline.project.namespace).to receive(:ingest_sbom_reports_available?)
          .and_return(ingest_sbom_reports_available)
        allow(Sbom::IngestReportsWorker).to receive(:perform_async)
      end

      context 'with include_manual_to_pipeline_completion FF disabled' do
        before do
          allow(pipeline).to receive(:include_manual_to_pipeline_completion_enabled?).and_return(false)
        end

        it_behaves_like 'ingesting sbom reports in a single pipeline'
      end

      context 'with include_manual_to_pipeline_completion FF enabled' do
        before do
          allow(pipeline).to receive(:include_manual_to_pipeline_completion_enabled?).and_return(true)
        end

        it_behaves_like 'ingesting sbom reports in a single pipeline'
      end
    end

    context 'with a parent-child pipeline hierarchy' do
      shared_examples_for 'ingesting sbom reports in a parent-child pipeline hierarchy' do
        context 'when the project does NOT have SBOM ingestion available' do
          let(:ingest_sbom_reports_available) { false }

          it 'does not schedule Sbom::IngestReportsWorker' do
            execute

            expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
          end
        end

        context 'when the project has SBOM ingestion available' do
          let(:ingest_sbom_reports_available) { true }

          context 'on a non-default branch' do
            let(:default_branch) { false }

            it 'does not schedule Sbom::IngestReportsWorker' do
              execute

              expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
            end
          end

          context 'on the default branch' do
            context 'when the whole pipeline hierarchy has not completed' do
              before do
                allow(child_pipeline_2).to receive(complete_method).and_return(false)
              end

              it 'does not schedule Sbom::IngestReportsWorker' do
                execute

                expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
              end
            end

            context 'when the whole pipeline hierarchy has completed' do
              context 'when no pipeline in the hierarchy has an SBOM report' do
                it 'does not schedule Sbom::IngestReportsWorker' do
                  execute

                  expect(::Sbom::IngestReportsWorker).not_to have_received(:perform_async)
                end

                # We test N+1 when there is no SBOM report so that the logic looks through all pipelines
                # and avoids early return when first encountering a report (which could mask N+1)
                it 'prevents N+1 queries' do
                  create(:ci_pipeline, :success, project: project, child_of: parent_pipeline)
                  control = ActiveRecord::QueryRecorder.new { described_class.new(pipeline).execute }
                  create(:ci_pipeline, :success, project: project, child_of: parent_pipeline)

                  expect { described_class.new(pipeline).execute }.not_to exceed_query_limit(control)
                end
              end

              context 'when at least one pipeline in the hierarchy has an SBOM report' do
                before do
                  create(:ee_ci_build, :cyclonedx, pipeline: child_pipeline_2)
                end

                it 'schedules Sbom::IngestReportsWorker' do
                  execute

                  expect(Sbom::IngestReportsWorker).to have_received(:perform_async).with(pipeline.root_ancestor.id)
                end
              end
            end
          end
        end
      end

      let_it_be(:parent_pipeline)  { create(:ci_pipeline, :success, project: project) }
      let_it_be(:child_pipeline_1) { create(:ci_pipeline, :success, project: project, child_of: parent_pipeline) }
      let_it_be(:child_pipeline_2) { create(:ci_pipeline, :success, project: project, child_of: parent_pipeline) }

      before do
        allow(pipeline).to receive(:default_branch?).and_return(default_branch)
        allow(pipeline.project.namespace).to receive(:ingest_sbom_reports_available?)
          .and_return(ingest_sbom_reports_available)
        allow(Sbom::IngestReportsWorker).to receive(:perform_async)
      end

      context 'with include_manual_to_pipeline_completion FF disabled' do
        let(:complete_method) { :complete? }

        before do
          allow(pipeline).to receive(:include_manual_to_pipeline_completion_enabled?).and_return(false)
        end

        context 'when the parent pipeline completes' do
          let(:pipeline) { parent_pipeline }

          it_behaves_like 'ingesting sbom reports in a parent-child pipeline hierarchy'
        end

        context 'when a child pipeline completes' do
          let(:pipeline) { child_pipeline_1 }

          it_behaves_like 'ingesting sbom reports in a parent-child pipeline hierarchy'
        end
      end

      context 'with include_manual_to_pipeline_completion FF enabled' do
        let(:complete_method) { :complete_or_manual? }

        before do
          allow(pipeline).to receive(:include_manual_to_pipeline_completion_enabled?).and_return(true)
        end

        context 'when the parent pipeline completes' do
          let(:pipeline) { parent_pipeline }

          it_behaves_like 'ingesting sbom reports in a parent-child pipeline hierarchy'
        end

        context 'when a child pipeline completes' do
          let(:pipeline) { child_pipeline_1 }

          it_behaves_like 'ingesting sbom reports in a parent-child pipeline hierarchy'
        end
      end
    end
  end
end
