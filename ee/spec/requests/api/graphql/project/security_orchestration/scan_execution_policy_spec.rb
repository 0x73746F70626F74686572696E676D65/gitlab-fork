# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).scanExecutionPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with project level scan execution policies'

  subject(:query_result) { graphql_data_at(:project, :scanExecutionPolicies, :nodes) }

  context 'when policy_configuration is assigned to the project' do
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_policy_reponse(policy)
          .merge(expected_project_source_response)
          .merge(expected_edit_path_response(project))
      ])
    end

    context 'when policy_scope is present in policy' do
      include_context 'with scan execution policy and policy_scope'

      it 'returns the policy' do
        expect(query_result).to match_array([
          expected_policy_reponse(policy)
            .merge(expected_policy_scope_response)
            .merge(expected_project_source_response)
            .merge(expected_edit_path_response(project))
        ])
      end
    end
  end

  context 'when policy_configuration is assigned to the group' do
    let_it_be(:project_variables) do
      {
        fullPath: project.full_path,
        relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['INHERITED'].graphql_name
      }
    end

    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: nil, namespace: group)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_reponse(policy, true)])
    end
  end
end
