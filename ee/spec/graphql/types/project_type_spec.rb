# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Project'] do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project, severity: :high) }

  let_it_be(:security_policy_management_project) { create(:project) }

  before do
    stub_licensed_features(security_dashboard: true)

    project.add_developer(user)
  end

  it 'includes the ee specific fields' do
    expected_fields = %w[
      security_training_providers vulnerabilities vulnerability_scanners requirement_states_count
      vulnerability_severities_count packages compliance_frameworks vulnerabilities_count_by_day
      security_dashboard_path iterations iteration_cadences repository_size_excess actual_repository_size_limit
      code_coverage_summary api_fuzzing_ci_configuration corpuses path_locks incident_management_escalation_policies
      incident_management_escalation_policy scan_execution_policies pipeline_execution_policies approval_policies
      security_policy_project security_training_urls vulnerability_images only_allow_merge_if_all_status_checks_passed
      security_policy_project_linked_projects security_policy_project_linked_namespaces
      dependencies merge_requests_disable_committers_approval has_jira_vulnerability_issue_creation_enabled
      ci_subscriptions_projects ci_subscribed_projects ai_agents ai_agent duo_features_enabled
      runner_cloud_provisioning google_cloud_artifact_registry_repository marked_for_deletion_on
      is_adjourned_deletion_enabled permanent_deletion_date ai_metrics saved_reply merge_trains
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'product analytics' do
    describe 'tracking_key' do
      where(
        :can_read_product_analytics,
        :project_instrumentation_key,
        :expected
      ) do
        false | nil | nil
        true  | 'snowplow-key' | 'snowplow-key'
        true  | nil | nil
      end

      with_them do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }

        before do
          allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
          project.project_setting.update!(product_analytics_instrumentation_key: project_instrumentation_key)

          stub_application_setting(product_analytics_enabled: can_read_product_analytics)
          stub_licensed_features(product_analytics: can_read_product_analytics)
        end

        let(:query) do
          %(
            query {
              project(fullPath: "#{project.full_path}") {
                trackingKey
              }
            }
          )
        end

        subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

        it 'returns the expected tracking_key' do
          tracking_key = subject.dig('data', 'project', 'trackingKey')
          expect(tracking_key).to eq(expected)
        end
      end
    end
  end

  describe 'security_scanners' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, sha: project.commit.id, ref: project.default_branch) }
    let_it_be(:user) { create(:user) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityScanners {
              enabled
              available
              pipelineRun
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      create(:ci_build, :success, :sast, pipeline: pipeline)
      create(:ci_build, :success, :dast, pipeline: pipeline)
      create(:ci_build, :success, :license_scanning, pipeline: pipeline)
      create(:ci_build, :pending, :secret_detection, pipeline: pipeline)
    end

    it 'returns a list of analyzers enabled for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'enabled')
      expect(query_result).to match_array(%w[SAST DAST SECRET_DETECTION])
    end

    it 'returns a list of analyzers which were run in the last pipeline for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'pipelineRun')
      expect(query_result).to match_array(%w[DAST SAST])
    end
  end

  describe 'vulnerabilities' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :detected, :critical, :with_finding, project: project, title: 'A terrible one!')
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilities {
              nodes {
                title
                severity
                state
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the project's vulnerabilities" do
      vulnerabilities = subject.dig('data', 'project', 'vulnerabilities', 'nodes')

      expect(vulnerabilities.count).to be(1)
      expect(vulnerabilities.first['title']).to eq('A terrible one!')
      expect(vulnerabilities.first['state']).to eq('DETECTED')
      expect(vulnerabilities.first['severity']).to eq('CRITICAL')
    end
  end

  describe 'code coverage summary field' do
    subject { described_class.fields['codeCoverageSummary'] }

    it { is_expected.to have_graphql_type(Types::Ci::CodeCoverageSummaryType) }
  end

  describe 'compliance_frameworks' do
    it 'queries in batches', :request_store, :use_clean_rails_memory_store_caching do
      projects = create_list(:project, 2, :with_compliance_framework)

      projects.each do |p|
        p.add_maintainer(user)
        # Cache warm up: runs authorization for each user.
        resolve_field(:id, p, current_user: user)
      end

      results = batch_sync(max_queries: 1) do
        projects.flat_map do |p|
          resolve_field(:compliance_frameworks, p, current_user: user)
        end
      end
      frameworks = results.flat_map(&:to_a)

      expect(frameworks).to match_array(projects.flat_map(&:compliance_management_frameworks))
    end
  end

  describe 'push rules field' do
    subject { described_class.fields['pushRules'] }

    it { is_expected.to have_graphql_type(Types::PushRulesType) }
  end

  shared_context 'is an orchestration policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project) }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
    end
  end

  describe 'scan_execution_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            scanExecutionPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated scan execution policies' do
      policies = subject.dig('data', 'project', 'scanExecutionPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'scan_result_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            scanResultPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated scan result policies' do
      policies = subject.dig('data', 'project', 'scanResultPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'approval_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            approvalPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated approval policies' do
      policies = subject.dig('data', 'project', 'approvalPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'pipeline_execution_policies', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            pipelineExecutionPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns associated approval policies' do
      policies = subject.dig('data', 'project', 'pipelineExecutionPolicies', 'nodes')

      expect(policies.count).to be(3)
    end
  end

  describe 'security_policy_project', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityPolicyProject {
              name
              fullPath
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProject')

      expect(result).to eq(
        'name' => security_policy_management_project.name,
        'fullPath' => security_policy_management_project.full_path
      )
    end
  end

  describe 'security_policy_project_linked_projects', feature_category: :security_policy_management do
    let(:query) do
      %(
        query {
          project(fullPath: "#{security_policy_management_project.full_path}") {
            securityPolicyProjectLinkedProjects {
              nodes {
                name
                fullPath
              }
            }
          }
        }
      )
    end

    include_context 'is an orchestration policy'

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProjectLinkedProjects', 'nodes', 0)

      expect(result).to eq(
        'name' => project.name,
        'fullPath' => project.full_path
      )
    end
  end

  describe 'security_policy_project_linked_namespaces', feature_category: :security_policy_management do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: namespace, security_policy_management_project: security_policy_management_project) }
    let(:query) do
      %(
        query {
          project(fullPath: "#{security_policy_management_project.full_path}") {
            securityPolicyProjectLinkedNamespaces {
              nodes {
                name
                fullPath
              }
            }
          }
        }
      )
    end

    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
      namespace.add_developer(user)
    end

    it 'returns the associated security policy project' do
      result = subject.dig('data', 'project', 'securityPolicyProjectLinkedNamespaces', 'nodes', 0)

      expect(result).to eq(
        'name' => namespace.name,
        'fullPath' => namespace.full_path
      )
    end
  end

  describe 'dora field' do
    subject { described_class.fields['dora'] }

    it { is_expected.to have_graphql_type(Types::DoraType) }
  end

  describe 'vulnerability_images' do
    let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: :cluster_image_scanning) }
    let_it_be(:finding) do
      create(
        :vulnerabilities_finding,
        :with_cluster_image_scanning_scanning_metadata,
        project: project,
        vulnerability: vulnerability
      )
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilityImages {
              nodes {
                name
              }
            }
          }
        }
      )
    end

    subject(:vulnerability_images) do
      result = GitlabSchema.execute(query, context: { current_user: current_user }).as_json
      result.dig('data', 'project', 'vulnerabilityImages', 'nodes', 0)
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.to be_nil }
    end

    context 'when user is logged in' do
      let(:current_user) { user }

      it 'returns a list of container images reported for vulnerabilities' do
        expect(vulnerability_images).to eq('name' => 'alpine:3.7')
      end
    end
  end

  describe 'has_jira_vulnerability_issue_creation_enabled' do
    let_it_be(:jira_integration) { create(:jira_integration, project: project) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            hasJiraVulnerabilityIssueCreationEnabled
          }
        }
      )
    end

    subject(:has_jira_vulnerability_issue_creation_enabled) do
      result = GitlabSchema.execute(query, context: { current_user: user }).as_json
      result.dig('data', 'project', 'hasJiraVulnerabilityIssueCreationEnabled')
    end

    context 'when jira integration is enabled' do
      before do
        allow_next_found_instance_of(::Integrations::Jira) do |jira_integration|
          allow(jira_integration).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(true)
        end
      end

      it 'returns true' do
        expect(has_jira_vulnerability_issue_creation_enabled).to be true
      end
    end

    context 'when jira integration is not enabled' do
      before do
        allow_next_found_instance_of(::Integrations::Jira) do |jira_integration|
          allow(jira_integration).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(false)
        end
      end

      it 'returns false' do
        expect(has_jira_vulnerability_issue_creation_enabled).to be false
      end
    end
  end

  describe 'aiAgents' do
    subject { described_class.fields['aiAgents'] }

    it { is_expected.to have_graphql_type(Types::Ai::Agents::AgentType.connection_type) }
    it { is_expected.to have_graphql_resolver(Resolvers::Ai::Agents::FindAgentResolver) }
  end

  describe 'runnerCloudProvisioning', feature_category: :runner do
    subject { described_class.fields['runnerCloudProvisioning'] }

    it { is_expected.to have_graphql_type(::Types::Ci::RunnerCloudProvisioningType) }
  end

  describe 'project adjourned deletion fields', feature_category: :groups_and_projects do
    let_it_be(:pending_delete_project) { create(:project, marked_for_deletion_at: Time.current) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{pending_delete_project.full_path}") {
            markedForDeletionOn
            isAdjournedDeletionEnabled
            permanentDeletionDate
          }
        }
      )
    end

    before do
      pending_delete_project.add_developer(user)
    end

    subject(:project_data) do
      result = GitlabSchema.execute(query, context: { current_user: user }).as_json
      {
        marked_for_deletion_on: result.dig('data', 'project', 'markedForDeletionOn'),
        is_adjourned_deletion_enabled: result.dig('data', 'project', 'isAdjournedDeletionEnabled'),
        permanent_deletion_date: result.dig('data', 'project', 'permanentDeletionDate')
      }
    end

    context 'with adjourned deletion disabled' do
      before do
        allow_next_found_instance_of(Project) do |project|
          allow(project).to receive(:adjourned_deletion?).and_return(false)
        end
      end

      it 'marked_for_deletion_on returns nil' do
        expect(project_data[:marked_for_deletion_on]).to be_nil
      end

      it 'is_adjourned_deletion_enabled returns false' do
        expect(project_data[:is_adjourned_deletion_enabled]).to be false
      end

      it 'permanent_deletion_date returns nil' do
        expect(project_data[:permanent_deletion_date]).to be_nil
      end
    end

    context 'with adjourned deletion enabled' do
      before do
        allow_next_found_instance_of(Project) do |project|
          allow(project).to receive(:adjourned_deletion?).and_return(true)
        end
      end

      it 'marked_for_deletion_on returns correct date' do
        marked_for_deletion_on_time = Time.zone.parse(project_data[:marked_for_deletion_on])

        expect(marked_for_deletion_on_time).to eq(pending_delete_project.marked_for_deletion_at.iso8601)
      end

      it 'is_adjourned_deletion_enabled returns true' do
        expect(project_data[:is_adjourned_deletion_enabled]).to be true
      end

      it 'permanent_deletion_date returns correct date' do
        expect(project_data[:permanent_deletion_date]).to eq(pending_delete_project.permanent_deletion_date(Time.now.utc).strftime('%F'))
      end
    end
  end
end
