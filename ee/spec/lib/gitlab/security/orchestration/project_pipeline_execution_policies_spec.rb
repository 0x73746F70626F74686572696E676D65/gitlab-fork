# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:namespace_policies_repository) { create(:project, :repository) }
  let_it_be(:namespace_security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace: namespace,
      security_policy_management_project: namespace_policies_repository
    )
  end

  let_it_be(:project) { create(:project, :repository, group: namespace) }
  let_it_be(:policies_repository) { create(:project, :repository, group: namespace) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policies_repository
    )
  end

  let(:namespace_policy_content) { { job: { script: 'group policy' } } }
  let(:namespace_policy) { build(:pipeline_execution_policy, content: namespace_policy_content) }

  let(:project_policy_content) { { job: { script: 'project policy' } } }
  let(:policy) { build(:pipeline_execution_policy, content: project_policy_content) }

  let(:empty_policy) { build(:pipeline_execution_policy, content: {}) }
  let(:disabled_policy) { build(:pipeline_execution_policy, enabled: false) }

  let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [policy, empty_policy]) }
  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy, disabled_policy])
  end

  let(:licensed_feature_enabled) { true }

  before do
    stub_licensed_features(security_orchestration_policies: licensed_feature_enabled)
    allow_next_instance_of(Repository, anything, anything, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end

    allow_next_instance_of(Repository, anything, namespace_policies_repository, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(namespace_policy_yaml)
    end
  end

  describe '#yaml_contents' do
    subject(:contents) { described_class.new(project).yaml_contents }

    let(:expected_contents) do
      [project_policy_content, namespace_policy_content].map(&:to_yaml)
    end

    it 'includes contents of policies' do
      expect(contents).to match_array(expected_contents)
    end

    context 'when feature is not licensed' do
      let(:licensed_feature_enabled) { false }

      it 'returns empty array' do
        expect(contents).to be_empty
      end
    end
  end
end
