# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreScansService, feature_category: :vulnerability_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(pipeline) }

    before do
      allow(described_class).to receive(:new).with(pipeline).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreScansService`' do
      execute

      expect(described_class).to have_received(:new).with(pipeline)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(pipeline) }

    let_it_be(:sast_build) { create(:ee_ci_build, pipeline: pipeline) }
    let_it_be(:dast_build) { create(:ee_ci_build, pipeline: pipeline) }
    let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: sast_build) }
    let_it_be(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: dast_build) }

    subject(:store_group_of_artifacts) { service_object.execute }

    before do
      allow(Security::StoreSecurityReportsByProjectWorker).to receive(:perform_async)
      allow(ScanSecurityReportSecretsWorker).to receive(:perform_async)
      allow(Security::StoreGroupedScansService).to receive(:execute)

      stub_licensed_features(sast: true, dast: false)
    end

    context 'when the pipeline already has a purged security scan' do
      before do
        create(:security_scan, status: :purged, build: sast_build)
      end

      it 'does not store the security scans' do
        store_group_of_artifacts

        expect(Security::StoreGroupedScansService).not_to have_received(:execute)
      end

      context 'when the pipeline is for the default branch' do
        before do
          allow(pipeline).to receive(:default_branch?).and_return(true)
        end

        it 'does not schedule the `StoreSecurityReportsByProjectWorker`' do
          store_group_of_artifacts

          expect(Security::StoreSecurityReportsByProjectWorker).not_to have_received(:perform_async)
        end
      end
    end

    context 'when the pipeline does not have a purged security scan' do
      shared_examples 'executes service and workers' do
        context 'for Security::StoreGroupedScansService' do
          it 'executes only for artifacts where the feature is available' do
            store_group_of_artifacts

            expect(Security::StoreGroupedScansService).to have_received(:execute).with([sast_artifact])
            expect(Security::StoreGroupedScansService).not_to have_received(:execute).with([dast_artifact])
          end
        end

        context 'for StoreSecurityReportsByProjectWorker' do
          context 'when the pipeline is for the default branch' do
            let(:project_id) { pipeline.project.id }
            let(:cache_key) { Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project_id) }

            before do
              allow(pipeline).to receive(:default_branch?).and_return(true)
            end

            it 'schedules the `StoreSecurityReportsByProjectWorker`' do
              store_group_of_artifacts

              expect(Security::StoreSecurityReportsByProjectWorker).to have_received(:perform_async).with(
                project_id
              )
            end

            it 'sets the expected redis cache value', :clean_gitlab_redis_shared_state do
              expect { store_group_of_artifacts }.to change {
                Gitlab::Redis::SharedState.with { |redis| redis.get(cache_key) }
              }.from(nil).to(pipeline.id.to_s)
            end
          end

          context 'when the pipeline is not for the default branch' do
            before do
              allow(pipeline).to receive(:default_branch?).and_return(false)
            end

            it 'does not schedule the `StoreSecurityReportsByProjectWorker`' do
              store_group_of_artifacts

              expect(Security::StoreSecurityReportsByProjectWorker).not_to have_received(:perform_async)
            end
          end
        end

        context 'for ScanSecurityReportSecretsWorker' do
          shared_examples 'does not revoke secret detection tokens' do
            it 'does not schedule the `ScanSecurityReportSecretsWorker`' do
              store_group_of_artifacts

              expect(ScanSecurityReportSecretsWorker).not_to have_received(:perform_async)
            end
          end

          describe 'scheduling the `ScanSecurityReportSecretsWorker `' do
            context 'when no secret detection security scans exist for the pipeline' do
              before do
                pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

                allow(Gitlab::CurrentSettings).to receive(:secret_detection_token_revocation_enabled?).and_return(true)
              end

              include_examples 'does not revoke secret detection tokens'
            end

            context 'when secret detection security scans exist for the pipeline' do
              let_it_be(:scan) { create(:security_scan, scan_type: :secret_detection, build: sast_build) }
              let_it_be(:finding) { create(:security_finding, scan: scan) }

              context 'and the pipeline is in a private project' do
                before do
                  pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

                  allow(Gitlab::CurrentSettings).to receive(
                    :secret_detection_token_revocation_enabled?).and_return(false)
                end

                include_examples 'does not revoke secret detection tokens'
              end

              context 'and secret detection token revocation setting is disabled' do
                before do
                  pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

                  allow(Gitlab::CurrentSettings).to receive(
                    :secret_detection_token_revocation_enabled?).and_return(false)
                end

                include_examples 'does not revoke secret detection tokens'
              end

              context 'and the pipeline is in a public project and the setting is enabled' do
                before do
                  pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

                  allow(Gitlab::CurrentSettings).to receive(
                    :secret_detection_token_revocation_enabled?).and_return(true)
                end

                it 'schedules the `ScanSecurityReportSecretsWorker`' do
                  store_group_of_artifacts

                  expect(ScanSecurityReportSecretsWorker).to have_received(:perform_async).with(pipeline.id)
                end
              end
            end
          end
        end

        context 'for SyncFindingsToApprovalRulesWorker with scan result policies' do
          let(:security_orchestration_policy_configuration) do
            create(:security_orchestration_policy_configuration, project: pipeline.project)
          end

          before do
            allow(pipeline.project).to receive(:all_security_orchestration_policy_configurations)
              .and_return([security_orchestration_policy_configuration])
          end

          context 'when security_orchestration_policies is not licensed' do
            before do
              stub_licensed_features(security_orchestration_policies: false)
            end

            it 'does not call SyncFindingsToApprovalRulesWorker' do
              expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to receive(:perform_async)

              store_group_of_artifacts
            end
          end

          context 'when security_orchestration_policies is licensed' do
            before do
              stub_licensed_features(security_orchestration_policies: true, sast: true)
            end

            context 'when the pipeline is not for the default branch' do
              before do
                allow(pipeline).to receive(:default_branch?).and_return(false)
              end

              it 'calls SyncFindingsToApprovalRulesWorker' do
                expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
                  .to receive(:perform_async).with(pipeline.id)

                store_group_of_artifacts
              end
            end

            context 'when the pipeline is for the default branch' do
              before do
                allow(pipeline).to receive(:default_branch?).and_return(true)
              end

              it 'does not call SyncFindingsToApprovalRulesWorker' do
                expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to receive(:perform_async)

                store_group_of_artifacts
              end
            end
          end
        end
      end

      context 'when StoreGroupedScansService.execute return false' do
        before do
          allow(pipeline).to receive(:default_branch?).and_return(true)
          allow(Security::StoreGroupedScansService).to receive(:execute).and_return(false)
        end

        it 'does not schedule the `ScanSecurityReportSecretsWorker`' do
          store_group_of_artifacts

          expect(ScanSecurityReportSecretsWorker).not_to have_received(:perform_async)
        end

        it 'does not schedule the `StoreSecurityReportsByProjectWorker`' do
          store_group_of_artifacts

          expect(Security::StoreSecurityReportsByProjectWorker).not_to have_received(:perform_async)
        end

        describe 'scheduling `SyncFindingsToApprovalRulesWorker`' do
          before do
            stub_licensed_features(security_orchestration_policies: true, sast: true)
          end

          context 'when the pipeline is for the default branch' do
            it 'does not schedule the `SyncFindingsToApprovalRulesWorker`' do
              expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to receive(:perform_async)

              store_group_of_artifacts
            end
          end

          context 'when the pipeline is not for the default branch' do
            before do
              allow(pipeline).to receive(:default_branch?).and_return(false)
            end

            it 'schedules the `SyncFindingsToApprovalRulesWorker`' do
              expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).to receive(:perform_async)

              store_group_of_artifacts
            end
          end
        end
      end

      context 'when StoreGroupedScansService.execute return true' do
        before do
          allow(Security::StoreGroupedScansService).to receive(:execute).and_return(true)
        end

        it_behaves_like 'executes service and workers'
      end

      context 'when include_manual_to_pipeline_completion is disabled' do
        before do
          allow(pipeline).to receive(:include_manual_to_pipeline_completion_enabled?).and_return(false)
        end

        it_behaves_like 'executes service and workers'
      end
    end
  end
end
