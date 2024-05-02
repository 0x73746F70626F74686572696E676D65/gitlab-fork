import { s__ } from '~/locale';
import { PIPELINE_EXECUTION_POLICY_TYPE_HEADER } from 'ee/security_orchestration/components/constants';

export const POLICY_SOURCE_OPTIONS = {
  ALL: {
    value: 'INHERITED',
    text: s__('SecurityOrchestration|All sources'),
  },
  DIRECT: {
    value: 'DIRECT',
    text: s__('SecurityOrchestration|Direct'),
  },
  INHERITED: {
    value: 'INHERITED_ONLY',
    text: s__('SecurityOrchestration|Inherited'),
  },
};

export const POLICY_TYPE_FILTER_OPTIONS = {
  ALL: {
    value: '',
    text: s__('SecurityOrchestration|All types'),
  },
  SCAN_EXECUTION: {
    value: 'SCAN_EXECUTION',
    text: s__('SecurityOrchestration|Scan execution'),
  },
  APPROVAL: {
    value: 'APPROVAL',
    text: s__('SecurityOrchestration|Merge request approval'),
  },
};

export const PIPELINE_EXECUTION_FILTER_OPTION = {
  PIPELINE_EXECUTION: {
    value: 'PIPELINE_EXECUTION',
    text: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
  },
};

export const POLICY_TYPES_WITH_INHERITANCE = [
  POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value,
  POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value,
];

export const EMPTY_LIST_DESCRIPTION = s__(
  'SecurityOrchestration|This %{namespaceType} does not contain any security policies.',
);

export const EMPTY_POLICY_PROJECT_DESCRIPTION = s__(
  'SecurityOrchestration|This %{namespaceType} is not linked to a security policy project',
);
