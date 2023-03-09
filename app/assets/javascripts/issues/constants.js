import { __ } from '~/locale';

export const STATUS_CLOSED = 'closed';
export const STATUS_MERGED = 'merged';
export const STATUS_OPEN = 'opened';
export const STATUS_REOPENED = 'reopened';

export const TITLE_LENGTH_MAX = 255;

export const TYPE_ALERT = 'alert';
export const TYPE_EPIC = 'epic';
export const TYPE_INCIDENT = 'incident';
export const TYPE_ISSUE = 'issue';
export const TYPE_MERGE_REQUEST = 'merge_request';
export const TYPE_TEST_CASE = 'test_case';

export const WORKSPACE_GROUP = 'group';
export const WORKSPACE_PROJECT = 'project';

export const IssuableStatusText = {
  [STATUS_CLOSED]: __('Closed'),
  [STATUS_OPEN]: __('Open'),
  [STATUS_REOPENED]: __('Open'),
};
