export { createPolicyObject, fromYaml } from './from_yaml';
export { policyToYaml } from './to_yaml';
export * from './rules';
export {
  approversOutOfSync,
  APPROVER_TYPE_DICT,
  APPROVER_TYPE_LIST_ITEMS,
  buildApprovalAction,
} from './actions';
export * from './settings';
export * from './vulnerability_states';
export * from './filters';

export const DEFAULT_SCAN_RESULT_POLICY = `type: approval_policy
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
`;

export const DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE = `type: approval_policy
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
    approvals_required: 1
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
`;
