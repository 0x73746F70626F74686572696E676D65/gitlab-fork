import { s__, __ } from '~/locale';

export const I18N_DASHBOARD_LIST = {
  title: s__('ProductAnalytics|Analytics dashboards'),
  description: s__(
    'ProductAnalytics|Dashboards are created by editing the projects dashboard files.',
  ),
  learnMore: __('Learn more.'),
  instrumentationDetails: s__('Product Analytics|Instrumentation details'),
  sdkHost: s__('Product Analytics|SDK Host'),
  sdkHostDescription: s__('Product Analytics|The host to send all tracking events to'),
  sdkAppId: s__('Product Analytics|SDK App ID'),
  sdkAppIdDescription: s__('Product Analytics|Identifies the sender of tracking events'),
};

export const EVENTS_TYPES = ['pageViews', 'featureUsages', 'clickEvents', 'events'];

export function isTrackedEvent(eventType) {
  return EVENTS_TYPES.includes(eventType);
}

export const PANEL_DISPLAY_TYPES = {
  DATA: 'data',
  PANEL: 'panel',
  CODE: 'code',
};

export const PANEL_DISPLAY_TYPE_ITEMS = [
  {
    type: PANEL_DISPLAY_TYPES.DATA,
    icon: 'table',
    title: s__('ProductAnalytics|Data'),
  },
  {
    type: PANEL_DISPLAY_TYPES.PANEL,
    icon: 'chart',
    title: s__('ProductAnalytics|Panel'),
  },
  {
    type: PANEL_DISPLAY_TYPES.CODE,
    icon: 'code',
    title: s__('ProductAnalytics|Code'),
  },
];

export const MEASURE_COLOR = '#00b140';
export const DIMENSION_COLOR = '#c3e6cd';

export const EVENTS_DB_TABLE_NAME = 'TrackedEvents';
export const SESSIONS_TABLE_NAME = 'Sessions';

export const ANALYTICS_FIELD_CATEGORIES = [
  {
    name: s__('ProductAnalytics|Pages'),
    category: 'pages',
  },
  {
    name: s__('ProductAnalytics|Users'),
    category: 'users',
  },
];

export const ANALYTICS_FIELDS = [
  {
    name: s__('ProductAnalytics|URL'),
    category: 'pages',
    dbField: 'url',
    icon: 'documents',
  },
  {
    name: s__('ProductAnalytics|Page Path'),
    category: 'pages',
    dbField: 'docPath',
    icon: 'documents',
  },
  {
    name: s__('ProductAnalytics|Page Title'),
    category: 'pages',
    dbField: 'pageTitle',
    icon: 'documents',
  },
  {
    name: s__('ProductAnalytics|Page Language'),
    category: 'pages',
    dbField: 'docEncoding',
    icon: 'documents',
  },
  {
    name: s__('ProductAnalytics|Host'),
    category: 'pages',
    dbField: 'docHost',
    icon: 'documents',
  },
  {
    name: s__('ProductAnalytics|Referer'),
    category: 'users',
    dbField: 'referer',
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|Language'),
    category: 'users',
    dbField: 'userLanguage',
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|Viewport'),
    category: 'users',
    dbField: 'vpSize',
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|Browser Family'),
    category: 'users',
    dbField: 'parsedUaUaFamily',
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|Browser'),
    category: 'users',
    dbField: ['parsedUaUaFamily', 'parsedUaUaVersion'],
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|OS'),
    category: 'users',
    dbField: 'parsedUaOsFamily',
    icon: 'user',
  },
  {
    name: s__('ProductAnalytics|OS Version'),
    category: 'users',
    dbField: ['parsedUaOsFamily', 'parsedUaOsVersion'],
    icon: 'user',
  },
];
