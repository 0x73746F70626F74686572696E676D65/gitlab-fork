const putPolicyScopeComplianceFrameworksToEndOfYaml = (yaml) =>
  yaml
    .replace('\npolicy_scope:\n  compliance_frameworks:\n    - id: 1\n    - id: 2', '')
    .concat('policy_scope:\n  compliance_frameworks:\n    - id: 1\n    - id: 2\n');

const putPolicyScopeProjectsToEndOfYaml = (yaml) =>
  yaml
    .replace('\npolicy_scope:\n  projects:\n    excluding:\n      - id: 1\n      - id: 2', '')
    .concat('policy_scope:\n  projects:\n    excluding:\n      - id: 1\n      - id: 2\n');

const SETTINGS = `approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
  prevent_approval_by_commit_author: true
  remove_approvals_with_new_commit: true
  require_password_to_approve: false
`;

const FALLBACK = `fallback_behavior:
  fail: closed
`;

export const mockScanExecutionActionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`;

export const mockScanExecutionActionProjectManifest = putPolicyScopeComplianceFrameworksToEndOfYaml(
  mockScanExecutionActionManifest,
);

export const mockPipelineExecutionActionManifest = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: ''
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
`;

export const mockApprovalActionManifest = `type: approval_policy
name: ''
description: ''
enabled: true
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockApprovalActionProjectManifest = putPolicyScopeComplianceFrameworksToEndOfYaml(
  mockApprovalActionManifest,
);

export const EXCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: `type: scan_execution_policy
name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`,
  PIPELINE_EXECUTION: `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: ''
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
`,
  APPROVAL_POLICY: `type: approval_policy
name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding:
      - id: 1
      - id: 2
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
`
    .concat(SETTINGS)
    .concat(FALLBACK),
};

export const EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: putPolicyScopeProjectsToEndOfYaml(EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: putPolicyScopeProjectsToEndOfYaml(
    EXCLUDING_PROJECTS_MOCKS.PIPELINE_EXECUTION,
  ),
  APPROVAL_POLICY: putPolicyScopeProjectsToEndOfYaml(EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY),
};

const replaceProjectKey = (value) => value.replace('excluding', 'including');

export const INCLUDING_PROJECTS_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_MOCKS.APPROVAL_POLICY),
};

export const INCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS = {
  SCAN_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.SCAN_EXECUTION),
  PIPELINE_EXECUTION: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.PIPELINE_EXECUTION),
  APPROVAL_POLICY: replaceProjectKey(EXCLUDING_PROJECTS_PROJECTS_LEVEL_MOCKS.APPROVAL_POLICY),
};
