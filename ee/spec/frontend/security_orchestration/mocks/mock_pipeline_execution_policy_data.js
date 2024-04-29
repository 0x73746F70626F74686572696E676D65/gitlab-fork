import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';

export const mockPipelineExecutionManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
enabled: false
rules: []
actions:
  - scan: custom
    ci_configuration: |
      include:
        project: gitlab-policies/js6
        id: 1
        ref: main
        file: test_path
`;

export const mockPipelineScanExecutionObject = {
  type: 'pipeline_execution_policy',
  name: 'Include external file',
  description: 'This policy enforces pipeline execution with configuration from external file',
  enabled: false,
  rules: [],
  actions: [
    {
      scan: 'custom',
      ci_configuration: {
        include: {
          id: 1,
          ref: 'main',
          file: 'test_path',
        },
      },
    },
  ],
};

export const mockProjectPipelineExecutionPolicy = {
  __typename: 'PipelineExecutionPolicy',
  name: `${mockPipelineScanExecutionObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockPipelineExecutionManifest,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockGroupPipelineExecutionPolicy = {
  __typename: 'PipelineExecutionPolicy',
  name: `${mockPipelineScanExecutionObject.name}-group`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockPipelineExecutionManifest,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_policy"',
  enabled: false,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockPipelineExecutionPoliciesResponse = [
  mockProjectPipelineExecutionPolicy,
  mockGroupPipelineExecutionPolicy,
];
