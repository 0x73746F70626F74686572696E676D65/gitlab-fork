import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const EVENTS_TYPES = ['pageViews', 'linkClickEvents', 'events'];

export function isRestrictedToEventType(eventType) {
  return EVENTS_TYPES.includes(eventType);
}

export const PANEL_VISUALIZATION_HEIGHT = '600px';

export const PANEL_DISPLAY_TYPES = {
  DATA: 'data',
  VISUALIZATION: 'visualization',
  CODE: 'code',
};

export const PANEL_DISPLAY_TYPE_ITEMS = [
  {
    type: PANEL_DISPLAY_TYPES.DATA,
    icon: 'table',
    title: s__('Analytics|Data'),
  },
  {
    type: PANEL_DISPLAY_TYPES.VISUALIZATION,
    icon: 'chart',
    title: s__('Analytics|Visualization'),
  },
  {
    type: PANEL_DISPLAY_TYPES.CODE,
    icon: 'code',
    title: s__('Analytics|Code'),
  },
];

export const MEASURE_COLOR = '#00b140';
export const DIMENSION_COLOR = '#c3e6cd';

export const EVENTS_TABLE_NAME = 'TrackedEvents';
export const SESSIONS_TABLE_NAME = 'Sessions';
export const RETURNING_USERS_TABLE_NAME = 'ReturningUsers';

export const TRACKED_EVENTS_KEY = 'trackedevents';

export const ANALYTICS_FIELD_CATEGORIES = [
  {
    name: s__('Analytics|Pages'),
    category: 'pages',
  },
  {
    name: s__('Analytics|Users'),
    category: 'users',
  },
  {
    name: s__('Analytics|Link clicks'),
    category: 'linkClicks',
  },
  {
    name: s__('Analytics|Custom events'),
    category: 'custom',
  },
];

export const ANALYTICS_FIELDS = [
  {
    name: s__('Analytics|URL'),
    category: 'pages',
    dbField: 'pageUrl',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Page Path'),
    category: 'pages',
    dbField: 'pageUrlpath',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Page Title'),
    category: 'pages',
    dbField: 'pageTitle',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Page Language'),
    category: 'pages',
    dbField: 'documentLanguage',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Host'),
    category: 'pages',
    dbField: 'pageUrlhosts',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Referer'),
    category: 'users',
    dbField: 'pageReferrer',
    icon: 'user',
  },
  {
    name: s__('Analytics|Language'),
    category: 'users',
    dbField: 'browserLanguage',
    icon: 'user',
  },
  {
    name: s__('Analytics|Viewport'),
    category: 'users',
    dbField: 'viewportSize',
    icon: 'user',
  },
  {
    name: s__('Analytics|Browser Family'),
    category: 'users',
    dbField: 'agentName',
    icon: 'user',
  },
  {
    name: s__('Analytics|Browser'),
    category: 'users',
    dbField: ['agentName', 'agentVersion'],
    icon: 'user',
  },
  {
    name: s__('Analytics|OS'),
    category: 'users',
    dbField: 'osName',
    icon: 'user',
  },
  {
    name: s__('Analytics|OS Version'),
    category: 'users',
    dbField: ['osName', 'osVersion'],
    icon: 'user',
  },
  {
    name: s__('Analytics|User Id'),
    category: 'users',
    dbField: 'userId',
    icon: 'user',
  },
  {
    name: s__('Analytics|Target URL'),
    category: 'linkClicks',
    dbField: ['targetUrl'],
    icon: 'link',
  },
  {
    name: s__('Analytics|Element ID'),
    category: 'linkClicks',
    dbField: ['elementId'],
    icon: 'link',
  },
  {
    name: s__('Analytics|Event Name'),
    category: 'custom',
    dbField: 'customEventName',
    icon: 'documents',
  },
  {
    name: s__('Analytics|Event Props'),
    category: 'custom',
    dbField: 'customEventProps',
    icon: 'documents',
  },
  {
    name: s__('Analytics|User Props'),
    category: 'custom',
    dbField: 'customUserProps',
    icon: 'user',
  },
];

export const NEW_DASHBOARD = () => ({
  title: '',
  description: '',
  panels: [],
  userDefined: true,
});

export const DEFAULT_VISUALIZATION_QUERY_STATE = () => ({
  query: {
    limit: 100,
  },
  measureType: '',
  measureSubType: '',
});
export const DEFAULT_VISUALIZATION_TITLE = '';
export const DEFAULT_SELECTED_VISUALIZATION_TYPE = '';

export const FILE_ALREADY_EXISTS_SERVER_RESPONSE = 'A file with this name already exists';
export const DEFAULT_DASHBOARD_LOADING_ERROR = s__(
  'Analytics|Something went wrong while loading the dashboard. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}.',
);
export const DASHBOARD_REFRESH_MESSAGE = s__(
  'Analytics|Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}.',
);

export const DASHBOARD_STATUS_BETA = 'beta';

export const EVENT_LABEL_CREATED_DASHBOARD = 'user_created_custom_dashboard';
export const EVENT_LABEL_EDITED_DASHBOARD = 'user_edited_custom_dashboard';
export const EVENT_LABEL_VIEWED_DASHBOARD_DESIGNER = 'user_viewed_dashboard_designer';
export const EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD = 'user_viewed_custom_dashboard';
export const EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD = 'user_viewed_builtin_dashboard';
export const EVENT_LABEL_VIEWED_DASHBOARD = 'user_viewed_dashboard';

export const EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER = 'user_viewed_visualization_designer';
export const EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION = 'user_created_custom_visualization';
export const EVENT_LABEL_USER_SUBMITTED_GITLAB_DUO_QUERY_FROM_VISUALIZATION_DESIGNER =
  'user_submitted_gitlab_duo_query_from_visualization_designer';
export const EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_HELPFUL =
  'user_feedback_gitlab_duo_query_in_visualization_designer_helpful';
export const EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_UNHELPFUL =
  'user_feedback_gitlab_duo_query_in_visualization_designer_unhelpful';
export const EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_WRONG =
  'user_feedback_gitlab_duo_query_in_visualization_designer_wrong';
export const VISUALIZATION_DESIGNER_GITLAB_DUO_CORRELATION_PROPERTY = 'correlation_id';

export const EVENT_LABEL_EXCLUDE_ANONYMISED_USERS = 'exclude_anonymised_users';

export const PANEL_TROUBLESHOOTING_URL = helpPagePath(
  '/user/analytics/analytics_dashboards#troubleshooting',
);

export const MEASURE = 'measure';
export const DIMENSION = 'dimension';
