import { PROJECT_DASHBOARD_TABS as PROJECT_DASHBOARD_TABS_CE } from '~/projects/your_work/constants';

import { __ } from '~/locale';

// Exports override for EE
// eslint-disable-next-line import/export
export * from '~/projects/your_work/constants';

export const INACTIVE_TAB = {
  text: __('Inactive'),
  value: 'removed',
};

// Exports override for EE
// eslint-disable-next-line import/export
export const PROJECT_DASHBOARD_TABS = [...PROJECT_DASHBOARD_TABS_CE, INACTIVE_TAB];
