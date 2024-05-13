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

export const mockScanExecutionActionProjectManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
`;

export const mockPipelineExecutionActionManifest = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
override_project_ci: false
content:
  include:
    project: ''
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
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
`;

export const mockApprovalActionProjectManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
policy_scope:
  compliance_frameworks:
    - id: 1
    - id: 2
`;
