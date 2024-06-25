# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config, feature_category: :pipeline_composition do
  let_it_be(:ci_yml) do
    <<-EOS
    sample_job:
      script:
      - echo 'test'
    EOS
  end

  describe 'with security orchestration policy' do
    let(:source) { 'push' }

    let(:ref) { 'master' }
    let_it_be_with_refind(:project) { create(:project, :repository) }

    let_it_be(:policies_repository) { create(:project, :repository) }
    let_it_be(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: policies_repository) }
    let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy)]) }

    let(:pipeline) { build(:ci_pipeline, project: project, ref: ref) }

    subject(:config) { described_class.new(ci_yml, pipeline: pipeline, project: project, source: source) }

    before do
      allow_next_instance_of(Repository) do |repository|
        # allow(repository).to receive(:ls_files).and_return(['.gitlab/security-policies/enforce-dast.yml'])
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    context 'when feature is not licensed' do
      it 'does not modify the config' do
        expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when policy is not applicable on branch from the pipeline' do
        let(:ref) { 'another-branch' }

        it 'does not modify the config' do
          expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
        end
      end

      context 'when policy is applicable on branch from the pipeline' do
        let(:ref) { 'master' }

        context 'when DAST profiles are not found' do
          it 'adds a job with error message' do
            expect(config.to_hash).to eq(
              stages: [".pre", "build", "test", "deploy", "dast", ".post"],
              sample_job: { script: ["echo 'test'"] },
              'dast-on-demand-0': { allow_failure: true, script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false' }
            )
          end
        end

        context 'when DAST profiles are found' do
          let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project, name: 'Scanner Profile') }
          let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project, name: 'Site Profile') }

          let(:expected_configuration) do
            {
              sample_job: {
                script: ["echo 'test'"]
              },
              'dast-on-demand-0': {
                stage: 'dast',
                image: { name: '$SECURE_ANALYZERS_PREFIX/dast:$DAST_VERSION$DAST_IMAGE_SUFFIX' },
                variables: {
                  DAST_VERSION: 5,
                  SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
                  GIT_STRATEGY: 'none'
                },
                allow_failure: true,
                script: ['/analyze'],
                artifacts: { access: 'developer', reports: { dast: 'gl-dast-report.json' } },
                dast_configuration: {
                  site_profile: dast_site_profile.name,
                  scanner_profile: dast_scanner_profile.name
                },
                rules: [
                  { if: '$CI_GITLAB_FIPS_MODE == "true"', variables: { DAST_IMAGE_SUFFIX: "-fips" } },
                  { if: '$CI_GITLAB_FIPS_MODE != "true"', variables: { DAST_IMAGE_SUFFIX: "" } }
                ]
              }
            }
          end

          it 'extends config with additional jobs' do
            expect(config.to_hash).to include(expected_configuration)
          end

          context 'when source is ondemand_dast_scan' do
            let(:source) { 'ondemand_dast_scan' }

            it 'does not modify the config' do
              expect(config.to_hash).to eq(sample_job: { script: ["echo 'test'"] })
            end
          end
        end
      end
    end
  end

  describe '#inject_pipeline_execution_policy_stages' do
    subject(:config) { described_class.new(ci_yml, project: project, pipeline_policy_context: pipeline_policy_context) }

    include_context 'with pipeline policy context'

    let(:ci_yml) do
      YAML.dump(
        rspec: {
          script: 'rspec'
        }
      )
    end

    it 'does not inject the reserved stages by default' do
      expect(config.stages).to contain_exactly('.pre', 'build', 'deploy', 'test', '.post')
    end

    shared_examples_for 'injects reserved policy stages' do
      let(:default_stages) { %w[.pre build test deploy .post] }

      it 'injects reserved stages into yaml_processor_result' do
        expect(config.stages).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
      end

      context 'when the config already specifies reserved stages' do
        let(:ci_yml) do
          YAML.dump(
            stages: ['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'],
            rspec: {
              script: 'rspec'
            }
          )
        end

        it 'does not inject the reserved stages multiple times' do
          expect(config.stages).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
        end
      end

      context 'when feature flag "pipeline_execution_policy_type" is disabled' do
        before do
          stub_feature_flags(pipeline_execution_policy_type: false)
        end

        it 'does not inject the reserved stages' do
          expect(config.stages).to eq(default_stages)
        end
      end
    end

    context 'when execution_policy_mode is true' do
      let(:execution_policy_dry_run) { true }

      it_behaves_like 'injects reserved policy stages'
    end

    context 'when execution_policy_pipelines are present' do
      let(:execution_policy_pipelines) { build_list(:ci_empty_pipeline, 2) }

      it_behaves_like 'injects reserved policy stages'
    end
  end
end
