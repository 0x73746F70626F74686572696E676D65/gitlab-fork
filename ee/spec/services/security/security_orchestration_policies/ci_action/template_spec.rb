# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiAction::Template,
  :yaml_processor_feature_flag_corectness,
  feature_category: :security_policy_management do
  describe '#config' do
    subject(:config) { described_class.new(action, ci_variables, ci_context, 0, opts).config }

    let_it_be(:ci_variables) do
      { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_DISABLED' => nil }
    end

    let(:ci_context) { Gitlab::Ci::Config::External::Context.new(user: user) }
    let(:user) { create(:user) }
    let(:opts) do
      {
        allow_restricted_variables_at_policy_level: allow_restricted_variables_at_policy_level,
        scan_execution_policies_with_latest_templates: scan_execution_policies_with_latest_templates
      }
    end

    let(:scan_execution_policies_with_latest_templates) { true }
    let(:allow_restricted_variables_at_policy_level) { true }

    shared_examples 'with template name for scan type' do
      it 'fetches template content using ::TemplateFinder' do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: template_name).and_call_original

        config
      end

      context 'when selected latest template' do
        before do
          action.merge!(template: 'latest')
        end

        it 'fetches latest template content using ::TemplateFinder' do
          expect(::TemplateFinder).to receive(:build)
            .with(:gitlab_ci_ymls, nil, name: "#{template_name}.latest")
            .and_call_original

          config
        end

        context 'when scan_execution_policies_with_latest_templates feature flag is disabled' do
          let(:scan_execution_policies_with_latest_templates) { false }

          it 'fetches default template content using ::TemplateFinder' do
            expect(::TemplateFinder).to receive(:build)
              .with(:gitlab_ci_ymls, nil, name: template_name)
              .and_call_original

            config
          end
        end
      end

      context 'when selected default template' do
        before do
          action.merge!(template: 'default')
        end

        it 'fetches default template content using ::TemplateFinder' do
          expect(::TemplateFinder).to receive(:build)
            .with(:gitlab_ci_ymls, nil, name: template_name)
            .and_call_original

          config
        end

        context 'when scan_execution_policies_with_latest_templates feature flag is disabled' do
          let(:scan_execution_policies_with_latest_templates) { false }

          it 'fetches default template content using ::TemplateFinder' do
            expect(::TemplateFinder).to receive(:build)
              .with(:gitlab_ci_ymls, nil, name: template_name)
              .and_call_original

            config
          end
        end
      end
    end

    shared_examples 'removes rules which disable jobs' do
      it 'removes rules matching EXCLUDED_VARIABLES_PATTERNS' do
        config.each do |key, configuration|
          expect(configuration[:rules]).not_to(
            match(array_including(hash_including(if: /_EXCLUDED_ANALYZERS|_DISABLED|_EXCLUDED_PATHS/))),
            "expected configuration '#{key}' not to disable jobs or exclude paths"
          )
        end
      end
    end

    context 'when action is valid' do
      context 'when scan type is secret_detection' do
        let_it_be(:action) { { scan: 'secret_detection', tags: ['runner-tag'] } }
        let_it_be(:template_name) { 'Jobs/Secret-Detection' }
        let_it_be(:ci_variables) do
          { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_IMAGE_SUFFIX' => 'suffix' }
        end

        it_behaves_like 'with template name for scan type'
        it_behaves_like 'removes rules which disable jobs'

        it 'merges template variables with ci variables and returns them as string' do
          expect(config[:'secret-detection-0']).to include(
            variables: hash_including(
              'SECRET_DETECTION_HISTORIC_SCAN' => 'false',
              'SECRET_DETECTION_IMAGE_SUFFIX' => 'suffix'
            )
          )
        end

        it 'returns prepared CI configuration with Secret Detection scans' do
          expected_configuration = {
            rules: [{ if: '$CI_COMMIT_BRANCH' }],
            script: ["/analyzer run"],
            tags: ['runner-tag'],
            stage: 'test',
            image: '$SECURE_ANALYZERS_PREFIX/secrets:$SECRETS_ANALYZER_VERSION$SECRET_DETECTION_IMAGE_SUFFIX',
            services: [],
            allow_failure: true,
            artifacts: {
              access: 'developer',
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            },
            variables: {
              GIT_DEPTH: '50',
              SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
              SECRETS_ANALYZER_VERSION: '6',
              SECRET_DETECTION_IMAGE_SUFFIX: 'suffix',
              SECRET_DETECTION_EXCLUDED_PATHS: '',
              SECRET_DETECTION_HISTORIC_SCAN: 'false'
            }
          }

          expect(config.deep_symbolize_keys).to eq('secret-detection-0': expected_configuration)
        end
      end

      context 'when scan type is container_scanning' do
        let_it_be(:action) { { scan: 'container_scanning', tags: ['runner-tag'] } }
        let_it_be(:template_name) { 'Jobs/Container-Scanning' }
        let_it_be(:ci_variables) { { 'GIT_STRATEGY' => 'fetch', 'VARIABLE_1' => 10 } }

        it_behaves_like 'with template name for scan type'
        it_behaves_like 'removes rules which disable jobs'

        it 'merges template variables with ci variables and returns them as string' do
          expect(config[:'container-scanning-0']).to include(
            variables: hash_including(
              'GIT_STRATEGY' => 'fetch',
              'VARIABLE_1' => 10
            )
          )
        end

        it 'returns prepared CI configuration for Container Scanning' do
          expected_configuration = {
            image: '$CS_ANALYZER_IMAGE$CS_IMAGE_SUFFIX',
            stage: 'test',
            tags: ['runner-tag'],
            allow_failure: true,
            artifacts: {
              access: 'developer',
              reports: {
                container_scanning: 'gl-container-scanning-report.json',
                cyclonedx: "**/gl-sbom-*.cdx.json"
              },
              paths: [
                'gl-container-scanning-report.json', 'gl-dependency-scanning-report.json', "**/gl-sbom-*.cdx.json"
              ]
            },
            dependencies: [],
            script: ['gtcs scan'],
            variables: {
              CS_ANALYZER_IMAGE: "$CI_TEMPLATE_REGISTRY_HOST/security-products/container-scanning:7",
              GIT_STRATEGY: 'fetch',
              VARIABLE_1: 10,
              CS_SCHEMA_MODEL: 15
            },
            rules: [
              {
                if: '$CI_COMMIT_BRANCH && ' \
                    '$CI_GITLAB_FIPS_MODE == "true" && $CS_ANALYZER_IMAGE !~ /-(fips|ubi)\z/',
                variables: { CS_IMAGE_SUFFIX: '-fips' }
              },
              { if: '$CI_COMMIT_BRANCH' }
            ]
          }

          expect(config.deep_symbolize_keys).to eq('container-scanning-0': expected_configuration)
        end
      end

      context 'when scan type is sast', :aggregate_failures do
        let_it_be(:action) { { scan: 'sast', tags: ['runner-tag'] } }
        let_it_be(:ci_variables) { { 'SAST_DISABLED' => nil } }
        let_it_be(:template_name) { 'Jobs/SAST' }

        let(:expected_jobs) do
          [
            :"sast-0",
            :"bandit-sast-0",
            :"eslint-sast-0",
            :"security-code-scan-sast-0",
            :"gosec-sast-0",
            *expected_jobs_with_excluded_variable_rules
          ]
        end

        let(:expected_jobs_with_excluded_variable_rules) do
          [
            :"kubesec-sast-0",
            :"pmd-apex-sast-0",
            :"semgrep-sast-0",
            :"sobelow-sast-0",
            :"spotbugs-sast-0"
          ]
        end

        it 'returns prepared CI configuration for SAST' do
          expected_jobs = [
            :"sast-0",
            :"bandit-sast-0",
            :"brakeman-sast-0",
            :"eslint-sast-0",
            :"flawfinder-sast-0",
            :"kubesec-sast-0",
            :"gosec-sast-0",
            :"mobsf-android-sast-0",
            :"mobsf-ios-sast-0",
            :"nodejs-scan-sast-0",
            :"phpcs-security-audit-sast-0",
            :"pmd-apex-sast-0",
            :"security-code-scan-sast-0",
            :"semgrep-sast-0",
            :"sobelow-sast-0",
            :"spotbugs-sast-0"
          ]

          expected_variables = {
            'SEARCH_MAX_DEPTH' => 4,
            'SECURE_ANALYZERS_PREFIX' => '$CI_TEMPLATE_REGISTRY_HOST/security-products',
            'SAST_IMAGE_SUFFIX' => '',
            'SAST_EXCLUDED_ANALYZERS' => '',
            'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp',
            'SCAN_KUBERNETES_MANIFESTS' => 'false'
          }

          expect(config[:variables]).to be_nil
          expect(config[:'sast-0'][:variables].stringify_keys).to include(expected_variables)
          expect(config.keys).to match_array(expected_jobs)
        end

        it_behaves_like 'with template name for scan type'
        it_behaves_like 'removes rules which disable jobs'

        context 'when SAST_EXCLUDED_ANALYZERS is provided as variable set in the policy' do
          let_it_be(:ci_variables) { { 'SAST_EXCLUDED_ANALYZERS' => 'semgrep' } }

          context 'when allow_restricted_variables_at_policy_level feature flag is disabled' do
            let(:allow_restricted_variables_at_policy_level) { false }

            it_behaves_like 'removes rules which disable jobs'
          end

          context 'when allow_restricted_variables_at_policy_level feature flag is enabled' do
            it 'does not remove SAST_EXCLUDED_ANALYZERS rule or variable' do
              expect(config[:'sast-0'][:variables].stringify_keys).to include(ci_variables)

              config.values_at(*expected_jobs_with_excluded_variable_rules).each do |configuration|
                expect(configuration[:rules]).to include(hash_including(if: /SAST_EXCLUDED_ANALYZERS/))
              end
            end
          end
        end
      end

      context 'when scan type is dependency_scanning', :aggregate_failures do
        let_it_be(:action) { { scan: 'dependency_scanning', tags: ['runner-tag'] } }
        let_it_be(:ci_variables) { { 'DEPENDENCY_SCANNING_DISABLED' => nil } }
        let_it_be(:template_name) { 'Jobs/Dependency-Scanning' }

        let(:expected_jobs) do
          [
            :"dependency-scanning-0",
            *expected_jobs_with_excluded_variable_rules
          ]
        end

        let(:expected_jobs_with_excluded_variable_rules) do
          [
            :"gemnasium-dependency-scanning-0",
            :"gemnasium-maven-dependency-scanning-0",
            :"gemnasium-python-dependency-scanning-0"
          ]
        end

        it 'returns prepared CI configuration for Dependency Scanning' do
          expected_variables = {
            'SECURE_ANALYZERS_PREFIX' => "$CI_TEMPLATE_REGISTRY_HOST/security-products",
            'DS_EXCLUDED_PATHS' => "spec, test, tests, tmp",
            'DS_MAJOR_VERSION' => 5
          }

          expect(config[:variables]).to be_nil
          expect(config[:'dependency-scanning-0'][:variables]).to include(expected_variables)
          expect(config.keys).to match_array(expected_jobs)
        end

        it_behaves_like 'with template name for scan type'
        it_behaves_like 'removes rules which disable jobs'

        context 'when DS_EXCLUDED_ANALYZERS is provided as variable set in the policy' do
          let_it_be(:ci_variables) { { 'DS_EXCLUDED_ANALYZERS' => 'gemnasium-maven' } }

          context 'when allow_restricted_variables_at_policy_level feature flag is disabled' do
            let(:allow_restricted_variables_at_policy_level) { false }

            it_behaves_like 'removes rules which disable jobs'
          end

          context 'when allow_restricted_variables_at_policy_level feature flag is enabled' do
            it 'does not remove DS_EXCLUDED_ANALYZERS rule' do
              config.values_at(*expected_jobs_with_excluded_variable_rules).each do |configuration|
                expect(configuration[:rules]).to include(hash_including(if: /DS_EXCLUDED_ANALYZERS/))
              end
            end
          end
        end
      end

      context 'when scan type is sast_iac', :aggregate_failures do
        let_it_be(:action) { { scan: 'sast_iac', tags: ['runner-tag'] } }
        let_it_be(:template_name) { 'Jobs/SAST-IaC' }

        it 'returns prepared CI configuration for SAST IaC' do
          expected_jobs = [
            :"iac-sast-0",
            :"kics-iac-sast-0"
          ]

          expect(config[:variables]).to be_nil
          expect(config.keys).to match_array(expected_jobs)
        end

        it_behaves_like 'with template name for scan type'
        it_behaves_like 'removes rules which disable jobs'
      end
    end
  end
end
