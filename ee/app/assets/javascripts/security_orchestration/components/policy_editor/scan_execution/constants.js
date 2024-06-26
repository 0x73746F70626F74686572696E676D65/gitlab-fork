import { __, s__ } from '~/locale';
import { REPORT_TYPE_SECRET_DETECTION } from '~/vue_shared/security_reports/constants';

export const DEFAULT_AGENT_NAME = '';
export const AGENT_KEY = 'agents';

export const SCAN_EXECUTION_RULES_PIPELINE_KEY = 'pipeline';
export const SCAN_EXECUTION_RULES_SCHEDULE_KEY = 'schedule';

export const SCAN_EXECUTION_RULES_LABELS = {
  [SCAN_EXECUTION_RULES_PIPELINE_KEY]: s__('ScanExecutionPolicy|Triggers:'),
  [SCAN_EXECUTION_RULES_SCHEDULE_KEY]: s__('ScanExecutionPolicy|Schedules:'),
};

export const ADD_CONDITION_LABEL = s__('ScanExecutionPolicy|Add new condition');
export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');

export const SCAN_EXECUTION_PIPELINE_RULE = 'pipeline';
export const SCAN_EXECUTION_SCHEDULE_RULE = 'schedule';

export const SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY = 'branch';
export const SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY = 'agent';
export const SCAN_EXECUTION_RULE_SCOPE_TYPE = {
  [SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY]: s__('ScanExecutionPolicy|branch'),
  [SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY]: s__('ScanExecutionPolicy|agent'),
};

export const SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY = 'daily';
export const SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY = 'weekly';
export const SCAN_EXECUTION_RULE_PERIOD_TYPE = {
  [SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY]: __('daily'),
  [SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY]: __('weekly'),
};

export const ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY = 'specific_tag';
export const ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY = 'selected_automatically';

export const TAGS_MODE_SELECTED_ITEMS = [
  {
    text: s__('ScanExecutionPolicy|has specific tag'),
    value: ACTION_RUNNER_TAG_MODE_SPECIFIC_TAG_KEY,
  },
  {
    text: s__('ScanExecutionPolicy|selected automatically'),
    value: ACTION_RUNNER_TAG_MODE_SELECTED_AUTOMATICALLY_KEY,
  },
];

export const DEFAULT_SCANNER = REPORT_TYPE_SECRET_DETECTION;

export const SCANNER_HUMANIZED_TEMPLATE = s__(
  'ScanExecutionPolicy|Run a %{scan} scan with the following options:',
);

export const SCANNER_HUMANIZED_TEMPLATE_ALT = s__(
  'ScanExecutionPolicy|Run %{scan} with the following options:',
);

export const POLICY_ACTION_BUILDER_TAGS_ERROR_KEY = 'tags';
export const POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY = 'profiles';

export const RUNNER_TAGS_PARSING_ERROR = s__(
  'SecurityOrchestration|Non-existing tags have been detected in the policy yaml. As a result, rule mode has been disabled. To enable rule mode, remove those non-existing tags from the policy yaml.',
);

export const DAST_SCANNERS_PARSING_ERROR = s__(
  'SecurityOrchestration|Non-existing DAST profiles have been detected in the policy yaml. As a result, rule mode has been disabled. To enable rule mode, remove those non-existing profiles from the policy yaml.',
);

export const ERROR_MESSAGE_MAP = {
  [POLICY_ACTION_BUILDER_TAGS_ERROR_KEY]: RUNNER_TAGS_PARSING_ERROR,
  [POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY]: DAST_SCANNERS_PARSING_ERROR,
};
export const RUN_SCAN_ACTION = 'run_scan_action';
export const EXECUTE_YAML_ACTION = 'execute_yaml_action';

export const SCAN_EXECUTION_ACTIONS = {
  [RUN_SCAN_ACTION]: s__('ScanExecutionPolicy|Run a scan'),
  [EXECUTE_YAML_ACTION]: s__('ScanExecutionPolicy|Run CI/CD code'),
};

export const SCAN_EXECUTION_ACTIONS_LISTBOX_ITEMS = Object.entries(
  SCAN_EXECUTION_ACTIONS,
).map(([value, text]) => ({ value, text }));
export const SCAN_EXECUTION_ACTIONS_KEYS = Object.keys(SCAN_EXECUTION_ACTIONS);

export const INSERTED_CODE_BLOCK = 'inserted_code_block';
export const LINKED_EXISTING_FILE = 'link_existing_file';
export const CUSTOM_ACTION_KEY = 'custom';

export const CUSTOM_ACTION_OPTIONS = {
  [INSERTED_CODE_BLOCK]: s__('ScanExecutionPolicy|Inserted CI code block'),
  [LINKED_EXISTING_FILE]: s__('ScanExecutionPolicy|Linked existing CI file'),
};

export const CUSTOM_ACTION_OPTIONS_KEYS = Object.keys(CUSTOM_ACTION_OPTIONS);
export const CUSTOM_ACTION_OPTIONS_LISTBOX_ITEMS = Object.entries(
  CUSTOM_ACTION_OPTIONS,
).map(([value, text]) => ({ value, text }));

export const INJECT = 'inject_ci';
export const OVERRIDE = 'override_project_ci';

export const CUSTOM_STRATEGY_OPTIONS = {
  [INJECT]: s__('ScanExecutionPolicy|Inject'),
  [OVERRIDE]: s__('ScanExecutionPolicy|Override'),
};

export const CUSTOM_STRATEGY_OPTIONS_KEYS = Object.keys(CUSTOM_STRATEGY_OPTIONS);
export const CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS = Object.entries(
  CUSTOM_STRATEGY_OPTIONS,
).map(([value, text]) => ({ value, text }));
