import { s__, __ } from '~/locale';

export const EDITOR_MODE_RULE = 'rule';
export const EDITOR_MODE_YAML = 'yaml';

export const PARSING_ERROR_MESSAGE = s__(
  'NetworkPolicies|Rule mode is unavailable for this policy. In some cases, we cannot parse the YAML file back into the rules editor.',
);

export const EDITOR_MODES = [
  { value: EDITOR_MODE_RULE, text: s__('NetworkPolicies|Rule mode') },
  { value: EDITOR_MODE_YAML, text: s__('NetworkPolicies|.yaml mode') },
];

export const DELETE_MODAL_CONFIG = {
  id: 'delete-modal',
  secondary: {
    text: s__('NetworkPolicies|Delete policy'),
    attributes: { variant: 'danger' },
  },
  cancel: {
    text: __('Cancel'),
  },
};

export const DEFAULT_MR_TITLE = s__('SecurityOrchestration|Update scan policies');

export const POLICY_RUN_TIME_MESSAGE = s__(
  'SecurityOrchestration|Allow up to 10 minutes for any policy changes to take effect.',
);

export const POLICY_RUN_TIME_TOOLTIP = s__(
  'SecurityOrchestration|Policies created in this project are applied through a background job that runs once every 10 minutes.',
);

export const SECURITY_POLICY_ACTIONS = Object.freeze({
  APPEND: 'APPEND',
  REMOVE: 'REMOVE',
  REPLACE: 'REPLACE',
});

export const GRAPHQL_ERROR_MESSAGE = s__(
  'SecurityOrchestration|There was a problem creating the new security policy',
);

export const NO_RULE_MESSAGE = s__('SecurityOrchestration|No rules defined - policy will not run.');

export const INVALID_BRANCHES = s__(
  'SecurityOrchestration|The following branches do not exist on this development project: %{branches}. Please review all branches to ensure the values are accurate before updating this policy.',
);
