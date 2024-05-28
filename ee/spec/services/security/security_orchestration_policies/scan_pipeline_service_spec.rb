# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ScanPipelineService,
  :yaml_processor_feature_flag_corectness,
  feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }

    let(:pipeline_scan_config) { subject[:pipeline_scan] }
    let(:on_demand_config) { subject[:on_demand] }
    let(:variables_config) { subject[:variables] }
    let(:service) { described_class.new(context) }
    let(:context) { Gitlab::Ci::Config::External::Context.new(project: project, user: user) }

    subject { service.execute(actions) }

    shared_examples 'creates scan jobs' do |on_demand_jobs: [], pipeline_scan_job_templates: [], variables: {}|
      it 'returns created jobs' do
        expect(::Security::SecurityOrchestrationPolicies::CiConfigurationService).to receive(:new)
          .exactly(pipeline_scan_job_templates.size)
          .times
          .and_call_original
        expect(::Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService).to receive(:new)
          .exactly(on_demand_jobs.count)
          .times
          .and_call_original

        pipeline_scan_jobs = []

        pipeline_scan_job_templates.each_with_index do |job_template, index|
          template = ::TemplateFinder.build(:gitlab_ci_ymls, nil, name: job_template).execute
          jobs = Gitlab::Ci::Config.new(template.content).jobs.keys
          jobs.each do |job|
            pipeline_scan_jobs.append(:"#{job.to_s.tr('_', '-')}-#{index}")
          end
        end

        expect(pipeline_scan_config.keys).to eq(pipeline_scan_jobs)
        expect(on_demand_config.keys).to eq(on_demand_jobs)
        expect(variables_config).to match a_hash_including(variables)
      end
    end

    context 'when there is an invalid action' do
      let(:actions) { [{ scan: 'invalid' }] }

      it 'does not create scan job' do
        expect(::Security::SecurityOrchestrationPolicies::CiConfigurationService).not_to receive(:new)
        expect(::Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService).not_to receive(:new)

        [pipeline_scan_config, on_demand_config].each do |config|
          expect(config.keys).to eq([])
        end
      end
    end

    context 'when there is only one action' do
      let(:actions) { [{ scan: 'secret_detection' }] }

      context 'when allow_restricted_variables_at_policy_level is disabled' do
        before do
          stub_feature_flags(allow_restricted_variables_at_policy_level: false)
        end

        it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': {} }
      end

      context 'when allow_restricted_variables_at_policy_level is enabled' do
        it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': { 'SECRET_DETECTION_EXCLUDED_PATHS' => '', 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' } }
      end
    end

    context 'when action contains variables overriding predefined ones' do
      let(:actions) { [{ scan: 'sast', variables: { SAST_EXCLUDED_ANALYZERS: 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location' } }] }

      it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/SAST], variables: { 'sast-0': { 'SAST_EXCLUDED_ANALYZERS' => 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location' } }

      it 'allows passing variables from the action into configuration service' do
        expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
          expect(ci_configuration_service).to receive(:execute).once
            .with(actions.first, { 'SAST_EXCLUDED_ANALYZERS' => 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location' }, context, 0).and_call_original
        end

        subject
      end
    end

    context 'when action contains the SECRET_DETECTION_HISTORIC_SCAN variable' do
      let(:actions) { [{ scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'true' } }] }

      context 'when SECRET_DETECTION_HISTORIC_SCAN is provided when initializing the service' do
        let(:service) { described_class.new(context, base_variables: { secret_detection: { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' } }) }

        context 'when allow_restricted_variables_at_policy_level is disabled' do
          before do
            stub_feature_flags(allow_restricted_variables_at_policy_level: false)
          end

          it 'ignores action variables and sets base_variables' do
            expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
              expect(ci_configuration_service).to receive(:execute).once
                .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' }, context, 0).and_call_original
            end

            subject
          end
        end

        context 'when allow_restricted_variables_at_policy_level is enabled' do
          it 'sets the value provided from action variables' do
            expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
              expect(ci_configuration_service).to receive(:execute).once
                .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
            end

            subject
          end
        end
      end
    end

    context 'when actions does not contain the SECRET_DETECTION_HISTORIC_SCAN variable' do
      let(:actions) { [{ scan: 'secret_detection', variables: {} }] }
      let(:service) { described_class.new(context, base_variables: { secret_detection: { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true' } }) }

      context 'when SECRET_DETECTION_HISTORIC_SCAN is provided when initializing the service' do
        it 'sets the value provided when initializing the service' do
          expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
            expect(ci_configuration_service).to receive(:execute).once
              .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
          end

          subject
        end
      end
    end

    context 'when there are multiple actions' do
      let(:actions) do
        [
          { scan: 'secret_detection' },
          { scan: 'dast', scanner_profile: 'Scanner Profile', site_profile: 'Site Profile' },
          { scan: 'cluster_image_scanning' },
          { scan: 'container_scanning' },
          { scan: 'sast' }
        ]
      end

      context 'when allow_restricted_variables_at_policy_level is disabled' do
        before do
          stub_feature_flags(allow_restricted_variables_at_policy_level: false)
        end

        it_behaves_like 'creates scan jobs',
          on_demand_jobs: %i[dast-on-demand-0],
          pipeline_scan_job_templates: %w[Jobs/Secret-Detection Jobs/Container-Scanning Jobs/SAST],
          variables: { 'container-scanning-1': {}, 'dast-on-demand-0': {}, 'sast-2': {}, 'secret-detection-0': {} }
      end

      context 'when allow_restricted_variables_at_policy_level is enabled' do
        it_behaves_like 'creates scan jobs',
          on_demand_jobs: %i[dast-on-demand-0],
          pipeline_scan_job_templates: %w[Jobs/Secret-Detection Jobs/Container-Scanning Jobs/SAST],
          variables: { 'container-scanning-1': {}, 'dast-on-demand-0': {}, 'sast-2': { 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp' }, 'secret-detection-0': { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' } }
      end
    end

    context 'when there are valid and invalid actions' do
      let(:actions) do
        [
          { scan: 'secret_detection' },
          { scan: 'invalid' }
        ]
      end

      context 'when allow_restricted_variables_at_policy_level is disabled' do
        before do
          stub_feature_flags(allow_restricted_variables_at_policy_level: false)
        end

        it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': {} }
      end

      context 'when allow_restricted_variables_at_policy_level is enabled' do
        it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' } }
      end
    end

    context 'with custom scan type' do
      let(:custom_ci_yaml_allowed) { true }
      let(:service) { described_class.new(context, custom_ci_yaml_allowed: custom_ci_yaml_allowed) }
      let(:actions) do
        [
          { scan: 'custom', ci_configuration: ci_configuration, variables: { 'CUSTOM_VARIABLE' => 'test' } }
        ]
      end

      let(:ci_configuration) do
        <<~CI_CONFIG
        image: busybox:latest
        custom:
          stage: build
          script:
            - echo "Defined in security policy"
        CI_CONFIG
      end

      context 'with the compliance_pipeline_in_policies feature disabled' do
        before do
          stub_feature_flags(compliance_pipeline_in_policies: false)
        end

        it { is_expected.to eq({ pipeline_scan: {}, on_demand: {}, variables: {} }) }
      end

      it { is_expected.to eq({ pipeline_scan: {}, on_demand: {}, variables: {} }) }

      context 'when toggle_security_policy_custom_ci is enabled for the group' do
        before_all do
          group.namespace_settings.update!(toggle_security_policy_custom_ci: true)
        end

        it { is_expected.to eq({ pipeline_scan: { image: "busybox:latest", custom: { stage: "build", script: ["echo \"Defined in security policy\""] } }, on_demand: {}, variables: { custom: { 'CUSTOM_VARIABLE' => 'test' } } }) }

        context 'when custom yaml is not allowed from configuration' do
          let(:custom_ci_yaml_allowed) { false }

          it { is_expected.to eq({ pipeline_scan: {}, on_demand: {}, variables: {} }) }
        end

        context 'with external CI file' do
          let(:external_project) do
            create(
              :project,
              :custom_repo,
              :public,
              files: {
                'ci-file.yaml' => ci_configuration.to_s
              }
            )
          end

          let(:actions) do
            [
              {
                scan: 'custom',
                ci_configuration_path: {
                  project: external_project.full_path,
                  file: 'ci-file.yaml',
                  ref: 'master'
                },
                variables: {
                  'CUSTOM_VARIABLE' => 'test'
                }
              }
            ]
          end

          it { is_expected.to eq({ pipeline_scan: { image: "busybox:latest", custom: { stage: "build", script: ["echo \"Defined in security policy\""] } }, on_demand: {}, variables: { custom: { 'CUSTOM_VARIABLE' => 'test' } } }) }
        end
      end

      context 'when CI does not define jobs' do
        let(:ci_configuration) do
          <<~CI_CONFIG
          variables:
            CUSTOM_VARIABLE: test
          CI_CONFIG
        end

        specify do
          expect { subject }.not_to raise_error
        end
      end
    end
  end
end
