/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `ScanResultManifest`
 * mock parsed yaml => name ends in `ScanResultObject`
 * mock policy for list/drawer => name ends in `ScanResultPolicy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarScanResultManifest and fooBarScanResultObject)
 * and keep them near each other.
 */
import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { actionId, ruleId } from './mock_data';

export const mockNoFallbackScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockDefaultBranchesScanResultManifest =
  mockNoFallbackScanResultManifest.concat(`fallback_behavior:
  fail: open
`);

export const mockDefaultBranchesScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
  fallback_behavior: {
    fail: 'open',
  },
};

export const mockBotMessageScanResultObject = {
  type: 'approval_policy',
  name: 'Add bot message',
  description: '',
  enabled: true,
  rules: [],
  actions: [
    { type: 'require_approval', approvals_required: 1 },
    { type: 'send_bot_message', enabled: true },
  ],
};

export const mockDeprecatedScanResultManifest = `type: scan_result_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
fallback_behavior:
  fail: open
`;

export const zeroActionsScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
`;

export const zeroActionsScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
};

export const tooManyActionsScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
  - type: other_type
`);

export const duplicateActionsScanResultManifest = zeroActionsScanResultManifest.concat(`actions:
  - type: require_approval
    approvals_required: 1
  - type: require_approval
    approvals_required: 1
`);

export const enabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: true
`);

export const disabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: false
`);

export const mockDeprecatedScanResultObject = {
  type: 'scan_result_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
};

export const mockProjectScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: `${mockDefaultBranchesScanResultObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  userApprovers: [],
  allGroupApprovers: [],
  roleApprovers: [],
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockGroupScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: `${mockDefaultBranchesScanResultObject.name}-group`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: mockDefaultBranchesScanResultObject.enabled,
  userApprovers: [],
  allGroupApprovers: [],
  roleApprovers: [],
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

export const mockApprovalSettingsScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
`;

export const mockApprovalSettingsPermittedInvalidScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
approval_settings:
  block_protected_branch_modification:
    enabled: true
`;

export const mockPolicyScopeScanResultManifest = `type: approval_policy
name: policy scope
description: This policy enforces policy scope
enabled: true
rules: []
actions: []
policy_scope:
  compliance_frameworks:
    - id: 26
`;

export const mockPolicyScopeScanResultObject = {
  type: 'approval_policy',
  name: 'policy scope',
  description: 'This policy enforces policy scope',
  enabled: true,
  rules: [],
  actions: [],
  policy_scope: {
    compliance_frameworks: [{ id: 26 }],
  },
};

export const mockApprovalSettingsScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
  },
};

export const mockApprovalSettingsScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: 'low vulnerability SAST approvals',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockApprovalSettingsScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  approval_settings: { block_branch_modification: true, prevent_pushing_and_force_pushing: true },
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockApprovalSettingsPermittedInvalidScanResultObject = {
  type: 'approval_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
  approval_settings: {
    block_protected_branch_modification: {
      enabled: true,
    },
  },
};

export const collidingKeysScanResultManifest = `---
name: This policy has colliding keys
description: This policy has colliding keys
enabled: true
rules:
  - type: scan_finding
    branches: []
    branch_type: protected
    scanners: []
    vulnerabilities_allowed: 0
    severity_levels: []
    vulnerability_states: []
actions:
  - type: require_approval
    approvals_required: 1
`;

export const mockWithBranchesScanResultManifest = `type: approval_policy
name: low vulnerability SAST approvals
description: This policy enforces low vulnerability SAST approvals
enabled: true
rules:
  - type: scan_finding
    branches:
      - main
    scanners:
      - sast
    vulnerabilities_allowed: 1
    severity_levels:
      - low
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockProjectWithBranchesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: 'low vulnerability SAST approvals',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockWithBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockProjectWithAllApproverTypesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: mockDefaultBranchesScanResultObject.name,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [{ fullPath: 'the.one.group' }],
  roleApprovers: ['OWNER'],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectFallbackOpenScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`fallback_behavior:\n  fail: open`);

export const mockProjectFallbackClosedScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`fallback_behavior:\n  fail: closed`);

export const mockScanResultPoliciesResponse = [
  mockProjectScanResultPolicy,
  mockGroupScanResultPolicy,
];

export const createRequiredApprovers = (count) => {
  const approvers = [];
  for (let i = 1; i <= count; i += 1) {
    let approver = { webUrl: `webUrl${i}` };
    if (i % 3 === 0) {
      approver = 'Owner';
    } else if (i % 2 === 0) {
      // eslint-disable-next-line no-underscore-dangle
      approver.__typename = 'UserCore';
      approver.name = `username${i}`;
      approver.id = `gid://gitlab/User/${i}`;
    } else {
      // eslint-disable-next-line no-underscore-dangle
      approver.__typename = 'Group';
      approver.fullPath = `grouppath${i}`;
      approver.id = `gid://gitlab/Group/${i}`;
    }
    approvers.push(approver);
  }
  return approvers;
};

export const mockFallbackInvalidScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`fallback_behavior:
  fail: something_else`);
