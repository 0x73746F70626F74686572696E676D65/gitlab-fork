import { s__ } from '~/locale';

export const STATE_OPEN = 'OPEN';
export const STATE_CLOSED = 'CLOSED';

export const STATE_EVENT_REOPEN = 'REOPEN';
export const STATE_EVENT_CLOSE = 'CLOSE';

export const TRACKING_CATEGORY_SHOW = 'workItems:show';

export const TASK_TYPE_NAME = 'Task';

export const WIDGET_TYPE_ASSIGNEES = 'ASSIGNEES';
export const WIDGET_TYPE_DESCRIPTION = 'DESCRIPTION';
export const WIDGET_TYPE_LABELS = 'LABELS';
export const WIDGET_TYPE_WEIGHT = 'WEIGHT';
export const WIDGET_TYPE_HIERARCHY = 'HIERARCHY';
export const WORK_ITEM_VIEWED_STORAGE_KEY = 'gl-show-work-item-banner';

export const WORK_ITEM_TYPE_ENUM_INCIDENT = 'INCIDENT';
export const WORK_ITEM_TYPE_ENUM_ISSUE = 'ISSUE';
export const WORK_ITEM_TYPE_ENUM_TASK = 'TASK';
export const WORK_ITEM_TYPE_ENUM_TEST_CASE = 'TEST_CASE';
export const WORK_ITEM_TYPE_ENUM_REQUIREMENTS = 'REQUIREMENTS';

export const i18n = {
  fetchError: s__('WorkItem|Something went wrong when fetching the work item. Please try again.'),
  updateError: s__('WorkItem|Something went wrong while updating the work item. Please try again.'),
  confidentialTooltip: s__(
    'WorkItem|Only project members with at least the Reporter role, the author, and assignees can view or be notified about this task.',
  ),
};

export const WIDGET_ICONS = {
  TASK: 'issue-type-task',
};

export const WORK_ITEM_STATUS_TEXT = {
  CLOSED: s__('WorkItem|Closed'),
  OPEN: s__('WorkItem|Open'),
};

export const WORK_ITEMS_TYPE_MAP = {
  [WORK_ITEM_TYPE_ENUM_INCIDENT]: {
    icon: `issue-type-incident`,
    name: s__('WorkItem|Incident'),
  },
  [WORK_ITEM_TYPE_ENUM_ISSUE]: {
    icon: `issue-type-issue`,
    name: s__('WorkItem|Issue'),
  },
  [WORK_ITEM_TYPE_ENUM_TASK]: {
    icon: `issue-type-task`,
    name: s__('WorkItem|Task'),
  },
  [WORK_ITEM_TYPE_ENUM_TEST_CASE]: {
    icon: `issue-type-test-case`,
    name: s__('WorkItem|Test case'),
  },
  [WORK_ITEM_TYPE_ENUM_REQUIREMENTS]: {
    icon: `issue-type-requirements`,
    name: s__('WorkItem|Requirements'),
  },
};
