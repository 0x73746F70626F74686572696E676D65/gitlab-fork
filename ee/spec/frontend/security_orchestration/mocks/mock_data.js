export const actionId = 'action_0';
export const ruleId = 'rule_0';

export const unsupportedManifest = `---
name: This policy has an unsupported attribute
enabled: false
UNSUPPORTED: ATTRIBUTE
rules:
- type: pipeline
  branches:
  - main
actions:
- scan: sast
`;

export const unsupportedManifestObject = {
  name: 'This policy has an unsupported attribute',
  enabled: false,
  UNSUPPORTED: 'ATTRIBUTE',
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [{ scan: 'sast', id: actionId }],
};

export const RUNNER_TAG_LIST_MOCK = [
  {
    id: 'gid://gitlab/Ci::Runner/1',
    tagList: ['macos', 'linux', 'docker'],
  },
  {
    id: 'gid://gitlab/Ci::Runner/2',
    tagList: ['backup', 'linux', 'development'],
  },
];

export const APPROVAL_POLICY_DEFAULT_POLICY = {
  type: 'approval_policy',
  name: '',
  description: '',
  enabled: true,
  rules: [{ type: '', id: 'rule_0' }],
  actions: [{ type: 'require_approval', approvals_required: 1, id: 'action_0' }],
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
    prevent_approval_by_commit_author: true,
    remove_approvals_with_new_commit: true,
    require_password_to_approve: false,
  },
  fallback_behavior: { fail: 'closed' },
};

export const APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE = {
  ...APPROVAL_POLICY_DEFAULT_POLICY,
  policy_scope: { projects: { excluding: [] } },
};

export const APPROVAL_POLICY_DEFAULT_POLICY_WITH_BOT_MESSAGE = {
  ...APPROVAL_POLICY_DEFAULT_POLICY,
  actions: [
    ...APPROVAL_POLICY_DEFAULT_POLICY.actions,
    { type: 'send_bot_message', enabled: true, id: 'action_1' },
  ],
};

export const SCAN_EXECUTION_DEFAULT_POLICY = {
  type: 'scan_execution_policy',
  name: '',
  description: '',
  enabled: true,
  rules: [{ type: 'pipeline', branches: ['*'], id: 'rule_0' }],
  actions: [{ scan: 'secret_detection', id: 'action_0' }],
};

export const SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE = {
  ...SCAN_EXECUTION_DEFAULT_POLICY,
  policy_scope: { projects: { excluding: [] } },
};

export const ASSIGNED_POLICY_PROJECT = {
  branch: 'main',
  fullPath: 'path/to/existing-project',
};

export const NEW_POLICY_PROJECT = {
  ...ASSIGNED_POLICY_PROJECT,
  fullPath: 'path/to/new-project',
};
