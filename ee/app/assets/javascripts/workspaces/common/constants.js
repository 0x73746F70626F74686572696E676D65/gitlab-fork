import { pick } from 'lodash';
import { s__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
export const WORKSPACE_STATES = {
  creationRequested: 'CreationRequested',
  starting: 'Starting',
  running: 'Running',
  stopping: 'Stopping',
  stopped: 'Stopped',
  terminating: 'Terminating',
  terminated: 'Terminated',
  failed: 'Failed',
  error: 'Error',
  unknown: 'Unknown',
};

export const WORKSPACE_DESIRED_STATES = {
  ...pick(WORKSPACE_STATES, 'running', 'stopped', 'terminated'),
  restartRequested: 'RestartRequested',
};
/* eslint-enable @gitlab/require-i18n-strings */

export const FILL_CLASS_GREEN = 'gl-fill-green-500';
export const FILL_CLASS_ORANGE = 'gl-fill-orange-500';
export const FILL_CLASS_RED = 'gl-fill-red-500';

export const EXCLUDED_WORKSPACE_AGE_IN_DAYS = 5;
export const WORKSPACES_DROPDOWN_GROUP_PAGE_SIZE = 20;

export const I18N_LOADING_WORKSPACES_FAILED = s__(
  'Workspaces|Unable to load current workspaces. Please try again or contact an administrator.',
);

export const WORKSPACES_LIST_PAGE_SIZE = 10;
export const WORKSPACES_LIST_POLL_INTERVAL = 3000;
