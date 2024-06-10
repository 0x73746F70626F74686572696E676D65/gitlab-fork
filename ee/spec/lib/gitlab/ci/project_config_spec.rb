# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Ci::ProjectConfig, feature_category: :continuous_integration do
  let_it_be_with_reload(:project) { create(:project, :repository, ci_config_path: nil) }
  let(:sha) { '123456' }
  let(:content) { nil }
  let(:source) { :push }
  let(:bridge) { nil }
  let(:triggered_for_branch) { true }
  let(:ref) { 'master' }
  let(:security_policies) { {} }
  let(:has_execution_policy_pipelines) { false }

  let(:content_result) do
    <<~CICONFIG
      ---
      include:
      - project: compliance/hippa
        file: ".compliance-gitlab-ci.yml"
    CICONFIG
  end

  subject(:config) do
    described_class.new(
      project: project,
      sha: sha,
      custom_content: content,
      pipeline_source: source,
      pipeline_source_bridge: bridge,
      triggered_for_branch: triggered_for_branch,
      ref: ref,
      has_execution_policy_pipelines: has_execution_policy_pipelines
    )
  end

  shared_examples 'does not include compliance pipeline configuration content' do
    it do
      expect(config.source).not_to eq(:compliance_source)
      expect(config.content).not_to eq(content_result)
    end
  end

  context 'when project has compliance label defined' do
    let(:compliance_group) { create(:group, :private, name: "compliance") }
    let(:compliance_project) { create(:project, namespace: compliance_group, name: "hippa") }

    context 'when feature is available' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
      end

      context 'when compliance pipeline configuration is defined' do
        let(:framework) do
          create(
            :compliance_framework,
            namespace: compliance_group,
            pipeline_configuration_full_path: ".compliance-gitlab-ci.yml@compliance/hippa"
          )
        end

        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it 'includes compliance pipeline configuration content' do
          expect(config.source).to eq(:compliance_source)
          expect(config.content).to eq(content_result)
        end

        context 'when pipeline is downstream of a bridge' do
          let(:bridge) { create(:ci_bridge) }

          it 'does include compliance pipeline configuration' do
            expect(config.source).to eq(:compliance_source)
            expect(config.content).to eq(content_result)
          end

          context 'when pipeline source is parent pipeline' do
            let(:source) { :parent_pipeline }

            it_behaves_like 'does not include compliance pipeline configuration content'
          end
        end

        context 'when the source is on-demand dast scan' do
          let(:source) { :ondemand_dast_scan }
          let(:content) { "---\ninclude:\n- template: DAST-On-Demand-Scan.gitlab-ci.yml\n" }
          let(:content_result) do
            <<~CICONFIG
              ---
              include:
              - template: DAST-On-Demand-Scan.gitlab-ci.yml
            CICONFIG
          end

          it 'does not include compliance pipeline configuration' do
            expect(config.source).to eq(:parameter_source)
            expect(config.content).to eq(content_result)
          end
        end
      end

      context 'when compliance pipeline configuration is not defined' do
        let(:framework) { create(:compliance_framework, namespace: compliance_group) }
        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end

      context 'when compliance pipeline configuration is empty' do
        let(:framework) do
          create(:compliance_framework, namespace: compliance_group, pipeline_configuration_full_path: '')
        end

        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: false)
      end

      it_behaves_like 'does not include compliance pipeline configuration content'
    end
  end

  context 'when project does not have compliance label defined' do
    context 'when feature is available' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
      end

      it_behaves_like 'does not include compliance pipeline configuration content'
    end

    context 'when project has active scan_execution policies' do
      let(:security_policies) { { enabled: true, policies: [security_policy_configuration] } }
      let!(:security_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      let(:policy) { build(:scan_execution_policy, enabled: true, rules: [rule]) }
      let(:branches) { %w[master production] }

      before do
        allow(project).to receive(:all_security_orchestration_policy_configurations)
                            .and_return([security_policy_configuration])

        allow(security_policy_configuration).to receive(:active_scan_execution_policies).and_return([policy])
      end

      context 'when policies should be enforced' do
        context 'when security_orchestration_policies feature is available' do
          before do
            stub_licensed_features(security_orchestration_policies: true)
          end

          let(:security_policy_default_content) { YAML.dump(nil) }

          context 'when auto devops is not enabled' do
            before do
              stub_application_setting(auto_devops_enabled: false)
            end

            context 'when active policies includes a rule with pipeline type' do
              let(:rule) { { type: 'pipeline', branches: branches } }

              context 'when policy applies to the pipeline\'s branch' do
                it 'includes security policies default pipeline configuration content' do
                  expect(config.source).to eq(:security_policies_default_source)
                  expect(config.content).to eq(security_policy_default_content)
                end
              end
            end
          end
        end
      end

      context 'when policies should not be enforced' do
        let(:rule) { { type: 'pipeline', branches: branches } }
        let(:licensed_security_orchestration_policies) { true }

        before do
          stub_licensed_features(security_orchestration_policies: licensed_security_orchestration_policies)
        end

        shared_examples 'does not include security policies default pipeline configuration content' do
          context 'when auto devops is not enabled' do
            before do
              stub_application_setting(auto_devops_enabled: false)
            end

            it 'does not include security policies default pipeline configuration content' do
              expect(config.source).to eq(nil)
            end
          end
        end

        context 'when security_orchestration_policies feature is not available' do
          let(:licensed_security_orchestration_policies) { false }

          it_behaves_like 'does not include security policies default pipeline configuration content'
        end

        context 'when is not triggered for branch' do
          let(:triggered_for_branch) { false }

          it_behaves_like 'does not include security policies default pipeline configuration content'
        end

        context 'when auto devops is enabled' do
          it 'does not include security policies default pipeline configuration content' do
            expect(config.source).to eq(:auto_devops_source)
          end
        end

        context 'when auto devops is not enabled' do
          before do
            stub_application_setting(auto_devops_enabled: false)
          end

          context 'when active policies does not include a rule with pipeline type' do
            let(:rule) { { type: 'schedule', branches: branches, cadence: '*/20 * * * *' } }

            it 'does not include security policies default pipeline configuration content' do
              expect(config.source).to eq(nil)
            end
          end

          context 'when policy does not apply to the branch' do
            let(:rule) { { type: 'pipeline', branches: ['main'] } }

            it 'does not include security policies default pipeline configuration content' do
              expect(config.source).to eq(nil)
            end
          end

          context 'when the policy should not be enforced to the pipeline source' do
            context 'when pipeline source is :parent_pipeline' do
              let(:source) { :parent_pipeline }

              it_behaves_like 'does not include security policies default pipeline configuration content'
            end

            context 'when pipeline source is :ondemand_dast_scan' do
              let(:source) { :ondemand_dast_scan }

              it_behaves_like 'does not include security policies default pipeline configuration content'
            end

            context 'when pipeline source is :container_registry_push' do
              let(:source) { :container_registry_push }

              it_behaves_like 'does not include security policies default pipeline configuration content'
            end
          end
        end
      end
    end

    context 'when project has active pipeline execution policies' do
      shared_examples_for 'forces the pipeline creation by including dummy content' do
        let(:expected_content) { YAML.dump(Gitlab::Ci::ProjectConfig::PipelineExecutionPolicyForced::DUMMY_CONTENT) }

        it 'includes dummy job to force the pipeline creation' do
          expect(config.source).to eq(:pipeline_execution_policy_forced)
          expect(config.content).to eq(expected_content)
        end
      end

      let(:has_execution_policy_pipelines) { true }

      it_behaves_like 'forces the pipeline creation by including dummy content'

      context 'when auto devops is not enabled' do
        before do
          stub_application_setting(auto_devops_enabled: false)
        end

        it_behaves_like 'forces the pipeline creation by including dummy content'
      end
    end
  end
end
