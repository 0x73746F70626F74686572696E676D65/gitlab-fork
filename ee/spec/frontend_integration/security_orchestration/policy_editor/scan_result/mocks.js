import { GROUP_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';

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

export const USER = {
  id: 2,
  name: 'Name 1',
  username: 'name.1',
  avatarUrl: 'https://www.gravatar.com/avatar/1234',
  type: USER_TYPE,
  __typename: 'UserCore',
};

export const GROUP = {
  avatarUrl: null,
  id: 1,
  fullName: 'Name 1',
  fullPath: 'path/to/name-1',
  type: GROUP_TYPE,
};

export const mockRoleApproversApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 2
    role_approvers:
      - developer
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockUserApproversApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 2
    user_approvers_ids:
      - ${USER.id}
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockGroupApproversApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 2
    group_approvers_ids:
      - ${GROUP.id}
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockLicenseApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: license_finding
    match_on_inclusion_license: true
    license_types: []
    license_states: []
    branch_type: protected
actions:
  - type: require_approval
    approvals_required: 1
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockSecurityApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: scan_finding
    scanners: []
    vulnerabilities_allowed: 0
    severity_levels: []
    vulnerability_states: []
    branch_type: protected
actions:
  - type: require_approval
    approvals_required: 1
`
  .concat(SETTINGS)
  .concat(FALLBACK);

export const mockAnyMergeRequestApprovalManifest = `type: approval_policy
name: ''
description: ''
enabled: true
rules:
  - type: any_merge_request
    branch_type: protected
    commits: any
actions:
  - type: require_approval
    approvals_required: 1
`
  .concat(SETTINGS)
  .concat(FALLBACK);
