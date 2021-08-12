import {
  getValueStreamTimeSummaryMetrics,
  getValueStreamSummaryMetrics,
} from '~/api/analytics_api';
import { __, s__ } from '~/locale';

export const DEFAULT_DAYS_IN_PAST = 30;
export const DEFAULT_DAYS_TO_DISPLAY = 30;
export const OVERVIEW_STAGE_ID = 'overview';

export const DEFAULT_VALUE_STREAM = {
  id: 'default',
  slug: 'default',
  name: 'default',
};

export const NOT_ENOUGH_DATA_ERROR = s__(
  "ValueStreamAnalyticsStage|We don't have enough data to show this stage.",
);

export const PAGINATION_TYPE = 'keyset';
export const PAGINATION_SORT_FIELD_END_EVENT = 'end_event';
export const PAGINATION_SORT_FIELD_DURATION = 'duration';
export const PAGINATION_SORT_DIRECTION_DESC = 'desc';
export const PAGINATION_SORT_DIRECTION_ASC = 'asc';

export const STAGE_TITLE_STAGING = 'staging';
export const STAGE_TITLE_TEST = 'test';

export const I18N_VSA_ERROR_STAGES = __(
  'There was an error fetching value stream analytics stages.',
);
export const I18N_VSA_ERROR_STAGE_MEDIAN = __('There was an error fetching median data for stages');
export const I18N_VSA_ERROR_SELECTED_STAGE = __(
  'There was an error fetching data for the selected stage',
);

export const OVERVIEW_METRICS = {
  TIME_SUMMARY: 'TIME_SUMMARY',
  RECENT_ACTIVITY: 'RECENT_ACTIVITY',
};

export const METRICS_POPOVER_CONTENT = {
  'lead-time': {
    description: s__('ValueStreamAnalytics|Median time from issue created to issue closed.'),
  },
  'cycle-time': {
    description: s__(
      'ValueStreamAnalytics|Median time from issue first merge request created to issue closed.',
    ),
  },
  'new-issue': { description: s__('ValueStreamAnalytics|Number of new issues created.') },
  'new-issues': { description: s__('ValueStreamAnalytics|Number of new issues created.') },
  deploys: { description: s__('ValueStreamAnalytics|Total number of deploys to production.') },
  'deployment-frequency': {
    description: s__('ValueStreamAnalytics|Average number of deployments to production per day.'),
  },
  commits: {
    description: s__('ValueStreamAnalytics|Number of commits pushed to the default branch'),
  },
};

export const projectMetricsRequests = (cycleAnalyticsForGroups = false) => {
  const summaryMetrics = [{ request: getValueStreamSummaryMetrics, name: __('recent activity') }];
  if (cycleAnalyticsForGroups) {
    return [{ request: getValueStreamTimeSummaryMetrics, name: __('time summary') }].concat(
      summaryMetrics,
    );
  }
  return summaryMetrics;
};
