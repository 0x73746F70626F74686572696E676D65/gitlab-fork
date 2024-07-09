import { __ } from '~/locale';

export const INDEX_ROUTE_NAME = 'index';
export const NEW_ROUTE_NAME = 'new';
export const DETAILS_ROUTE_NAME = 'details';
export const EDIT_ROUTE_NAME = 'edit';

export const SCOPED_LABEL_COLOR = '#CBE2F9';
export const UNSCOPED_LABEL_COLOR = '#DCDCDE';

export const INITIAL_PAGE = 1;
export const PAGE_SIZE = 10;

export const ENTITY_GROUP = 'group';
export const ENTITY_PROJECT = 'project';

// Dummy values for now. They may change when API is available
export const ROTATION_PERIOD_TWO_WEEKS = {
  value: '14',
  text: __('Every 2 weeks'),
};

export const ROTATION_PERIOD_MONTH = {
  value: '60',
  text: __('Every month'),
};

export const ROTATION_PERIOD_THREE_MONTHS = {
  value: '180',
  text: __('Every three months'),
};
export const ROTATION_PERIOD_OPTIONS = [
  ROTATION_PERIOD_TWO_WEEKS,
  ROTATION_PERIOD_MONTH,
  ROTATION_PERIOD_THREE_MONTHS,
];
