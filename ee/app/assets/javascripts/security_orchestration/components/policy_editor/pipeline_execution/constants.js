import { s__ } from '~/locale';

export const DEFAULT_PIPELINE_EXECUTION_POLICY = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: ''
`;

export const DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
policy_scope:
  projects:
    excluding: []
content:
  include:
    - project: ''
`;

export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');
