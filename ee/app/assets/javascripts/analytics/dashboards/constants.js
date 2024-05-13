import { GREEN_400, ORANGE_400, RED_400, GRAY_400 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__, __, n__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  MERGE_REQUEST_METRICS,
  CONTRIBUTOR_METRICS,
} from '~/analytics/shared/constants';

export const UNITS = {
  COUNT: 'COUNT',
  DAYS: 'DAYS',
  PER_DAY: 'PER_DAY',
  PERCENT: 'PERCENT',
};

// Limits the number of decimals we round values to
export const MAX_METRIC_PRECISION = 4;

export const SUPPORTED_DORA_METRICS = [
  DORA_METRICS.DEPLOYMENT_FREQUENCY,
  DORA_METRICS.LEAD_TIME_FOR_CHANGES,
  DORA_METRICS.TIME_TO_RESTORE_SERVICE,
  DORA_METRICS.CHANGE_FAILURE_RATE,
];

export const SUPPORTED_FLOW_METRICS = [
  FLOW_METRICS.LEAD_TIME,
  FLOW_METRICS.CYCLE_TIME,
  FLOW_METRICS.ISSUES,
  FLOW_METRICS.ISSUES_COMPLETED,
  FLOW_METRICS.DEPLOYS,
  FLOW_METRICS.MEDIAN_TIME_TO_MERGE,
];

export const SUPPORTED_MERGE_REQUEST_METRICS = [MERGE_REQUEST_METRICS.THROUGHPUT];

export const SUPPORTED_VULNERABILITY_METRICS = [
  VULNERABILITY_METRICS.CRITICAL,
  VULNERABILITY_METRICS.HIGH,
];

export const SUPPORTED_CONTRIBUTOR_METRICS = [CONTRIBUTOR_METRICS.COUNT];

export const TABLE_METRICS = {
  [DORA_METRICS.DEPLOYMENT_FREQUENCY]: {
    label: s__('DORA4Metrics|Deployment frequency'),
    units: UNITS.PER_DAY,
  },
  [DORA_METRICS.LEAD_TIME_FOR_CHANGES]: {
    label: s__('DORA4Metrics|Lead time for changes'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.TIME_TO_RESTORE_SERVICE]: {
    label: s__('DORA4Metrics|Time to restore service'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.CHANGE_FAILURE_RATE]: {
    label: s__('DORA4Metrics|Change failure rate'),
    invertTrendColor: true,
    units: UNITS.PERCENT,
  },
  [FLOW_METRICS.LEAD_TIME]: {
    label: s__('DORA4Metrics|Lead time'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [FLOW_METRICS.CYCLE_TIME]: {
    label: s__('DORA4Metrics|Cycle time'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [FLOW_METRICS.ISSUES]: {
    label: s__('DORA4Metrics|Issues created'),
    units: UNITS.COUNT,
  },
  [FLOW_METRICS.ISSUES_COMPLETED]: {
    label: s__('DORA4Metrics|Issues closed'),
    units: UNITS.COUNT,
    valueLimit: {
      max: 10001,
      mask: '10000+',
      description: s__(
        'DORA4Metrics|This is a lower-bound approximation. Your group has too many issues and MRs to calculate in real time.',
      ),
    },
  },
  [FLOW_METRICS.DEPLOYS]: {
    label: s__('DORA4Metrics|Deploys'),
    units: UNITS.COUNT,
  },
  [MERGE_REQUEST_METRICS.THROUGHPUT]: {
    label: s__('DORA4Metrics|Merge request throughput'),
    units: UNITS.COUNT,
  },
  [FLOW_METRICS.MEDIAN_TIME_TO_MERGE]: {
    label: s__('DORA4Metrics|Median time to merge'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [CONTRIBUTOR_METRICS.COUNT]: {
    label: s__('DORA4Metrics|Contributor count'),
    units: UNITS.COUNT,
  },
  [VULNERABILITY_METRICS.CRITICAL]: {
    label: s__('DORA4Metrics|Critical vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
  [VULNERABILITY_METRICS.HIGH]: {
    label: s__('DORA4Metrics|High vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
};

export const METRICS_WITH_NO_TREND = [VULNERABILITY_METRICS.CRITICAL, VULNERABILITY_METRICS.HIGH];
export const METRICS_WITH_LABEL_FILTERING = [
  FLOW_METRICS.ISSUES,
  FLOW_METRICS.ISSUES_COMPLETED,
  FLOW_METRICS.CYCLE_TIME,
  FLOW_METRICS.LEAD_TIME,
  MERGE_REQUEST_METRICS.THROUGHPUT,
];
export const METRICS_WITHOUT_LABEL_FILTERING = Object.keys(TABLE_METRICS).filter(
  (metric) => !METRICS_WITH_LABEL_FILTERING.includes(metric),
);

export const DASHBOARD_TITLE = s__('DORA4Metrics|Value Streams Dashboard');
export const DASHBOARD_DESCRIPTION = s__(
  'DORA4Metrics|The Value Streams Dashboard allows all stakeholders from executives to individual contributors to identify trends, patterns, and opportunities for software development improvements.',
);
export const DASHBOARD_SURVEY_LINK =
  'https://gitlab.fra1.qualtrics.com/jfe/form/SV_50guMGNU2HhLeT4';
export const DASHBOARD_DOCS_LINK = helpPagePath('user/analytics/value_streams_dashboard');
export const DASHBOARD_DESCRIPTION_GROUP = s__('DORA4Metrics|Metrics comparison for %{name} group');
export const DASHBOARD_DESCRIPTION_PROJECT = s__(
  'DORA4Metrics|Metrics comparison for %{name} project',
);
export const DASHBOARD_LOADING_FAILURE = s__('DORA4Metrics|Some metric comparisons failed to load');
export const DASHBOARD_NAMESPACE_LOAD_ERROR = s__(
  'DORA4Metrics|Failed to load comparison chart for Namespace: %{fullPath}',
);
export const DASHBOARD_LABELS_LOAD_ERROR = s__(
  'DORA4Metrics|Failed to load labels matching the filter: %{labels}',
);

export const CHART_GRADIENT = ['#499767', '#5252B5'];
export const CHART_GRADIENT_INVERTED = [...CHART_GRADIENT].reverse();
export const CHART_LOADING_FAILURE = s__('DORA4Metrics|Some metric charts failed to load');

export const CHART_TOOLTIP_UNITS = {
  [UNITS.COUNT]: undefined,
  [UNITS.DAYS]: __('days'),
  [UNITS.PER_DAY]: __('/day'),
  [UNITS.PERCENT]: '%',
};

export const YAML_CONFIG_PATH = '.gitlab/analytics/dashboards/value_streams/value_streams.yaml';
export const YAML_CONFIG_LOAD_ERROR = s__(
  'DORA4Metrics|Failed to load YAML config from Project: %{fullPath}',
);

export const ALERT_TEXT = s__(
  'DORA4Metrics|To help us improve the Value Stream Management Dashboard, please share feedback about your experience in this %{linkStart}survey%{linkEnd}.',
);

export const ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT = s__(
  'DORA4Metrics|To see usage overview, you must %{linkStart}enable background aggregation%{linkEnd}',
);

export const BACKGROUND_AGGREGATION_DOCS_LINK = helpPagePath(
  'user/analytics/value_streams_dashboard.html',
  { anchor: 'enable-or-disable-overview-background-aggregation' },
);

export const DORA_PERFORMERS_SCORE_CATEGORY_TYPES = {
  HIGH: 'highProjectsCount',
  MEDIUM: 'mediumProjectsCount',
  LOW: 'lowProjectsCount',
  NO_DATA: 'noDataProjectsCount',
};

export const DORA_PERFORMERS_SCORE_CATEGORIES = {
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.HIGH]: s__('DORA4Metrics|High'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.MEDIUM]: s__('DORA4Metrics|Medium'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.LOW]: s__('DORA4Metrics|Low'),
  [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.NO_DATA]: s__('DORA4Metrics|Not included'),
};

export const DORA_PERFORMERS_SCORE_METRICS = [
  // score definitions are listed in order from 'High' to 'Low' and accessed using the series index
  {
    label: s__('DORA4Metrics|Deployment frequency (Velocity)'),
    scoreDefinitions: [
      s__('DORA4Metrics|Have 30 or more deploys to production per day.'),
      s__('DORA4Metrics|Have between 1 to 29 deploys to production per day.'),
      s__('DORA4Metrics|Have less than 1 deploy to production per day.'),
    ],
  },
  {
    label: s__('DORA4Metrics|Lead time for changes (Velocity)'),
    scoreDefinitions: [
      s__(
        'DORA4Metrics|Took 7 days or less to go from code committed to code successfully running in production.',
      ),
      s__(
        'DORA4Metrics|Took between 8 to 29 days to go from code committed to code successfully running in production.',
      ),
      s__(
        'DORA4Metrics|Took more than 30 days to go from code committed to code successfully running in production.',
      ),
    ],
  },
  {
    label: s__('DORA4Metrics|Time to restore service (Quality)'),
    scoreDefinitions: [
      s__(
        'DORA4Metrics|Took 1 day or less to restore service when a service incident or a defect that impacts users occurs.',
      ),
      s__(
        'DORA4Metrics|Took between 2 to 6 days to restore service when a service incident or a defect that impacts users occurs.',
      ),
      s__(
        'DORA4Metrics|Took more than 7 days to restore service when a service incident or a defect that impacts users occurs.',
      ),
    ],
  },
  {
    label: s__('DORA4Metrics|Change failure rate (Quality)'),
    scoreDefinitions: [
      sprintf(
        s__('DORA4Metrics|Made 15%% or less changes to production resulted in degraded service.'),
      ),
      sprintf(
        s__(
          'DORA4Metrics|Made between 16%% to 44%% of changes to production resulted in degraded service.',
        ),
      ),
      sprintf(
        s__(
          'DORA4Metrics|Made more than 45%% of changes to production resulted in degraded service.',
        ),
      ),
    ],
  },
];

export const DORA_PERFORMERS_SCORE_DEFAULT_PANEL_TITLE = s__('DORA4Metrics|DORA performers score');

export const DORA_PERFORMERS_SCORE_PANEL_TITLE_WITH_PROJECTS_COUNT = s__(
  'DORA4Metrics|Total projects (%{count}) with DORA metrics',
);

export const DORA_PERFORMERS_SCORE_TOOLTIP_PROJECTS_COUNT_TITLE = (count) =>
  n__('DORA4Metrics|%d project', 'DORA4Metrics|%d projects', count);

export const DORA_PERFORMERS_SCORE_NOT_INCLUDED = (count) =>
  n__('DORA4Metrics|Has no calculated data.', 'DORA4Metrics|Have no calculated data.', count);

export const DORA_PERFORMERS_SCORE_LOADING_ERROR = s__(
  'DORA4Metrics|Failed to load DORA performance scores for Group: %{fullPath}',
);

export const DORA_PERFORMERS_SCORE_GROUP_ERROR = s__(
  'DORA4Metrics|Failed to load Group: %{fullPath}',
);

export const DORA_PERFORMERS_SCORE_PROJECT_ERROR = s__(
  'DORA4Metrics|This visualization is not supported for project namespaces.',
);

export const DORA_PERFORMERS_SCORE_NO_DATA = s__(
  'DORA4Metrics|No data available for Group: %{fullPath}',
);

export const DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE = [GREEN_400, ORANGE_400, RED_400, GRAY_400];

// The URL name already in use is `value_streams_dashboard`,
// the slug name for a dashboard must match the URL path that is used
export const BUILT_IN_VALUE_STREAM_DASHBOARD = 'value_streams_dashboard';

// The URL for shared analytics dashboards is based on the name of the YAML config
// YAML configured VSD uses `/value_streams` for the custom file name
export const CUSTOM_VALUE_STREAM_DASHBOARD = 'value_streams';

export const AI_IMPACT_DASHBOARD = 'ai_impact';

export const BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS = ['behavior', 'audience'];

export const PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID =
  'product_analytics_dashboard_feedback';
export const PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK =
  'https://gitlab.fra1.qualtrics.com/jfe/form/SV_4G9Mp4aDd1o8kpo';
