import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';

/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `Manifest`
 * mock parsed yaml => name ends in `Object`
 * mock policy for list/drawer => name ends in `Policy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarManifest and fooBarObject)
 * and keep them near each other.
 */

export const customYaml = `variable: true
`;

export const customYamlObject = { variable: true };

export const mockWithoutRefPipelineExecutionManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const mockWithoutRefPipelineExecutionObject = fromYaml({
  manifest: mockWithoutRefPipelineExecutionManifest,
});

export const invalidStrategyManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: this_is_wrong
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const mockPipelineExecutionManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
enabled: false
content:
   include:
     - project: gitlab-policies/js6
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
      content: 'include:\n project: gitlab-policies/js9 id: 27 ref: main file: README.md',
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
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockPipelineExecutionPoliciesResponse = [
  mockProjectPipelineExecutionPolicy,
  mockGroupPipelineExecutionPolicy,
];
