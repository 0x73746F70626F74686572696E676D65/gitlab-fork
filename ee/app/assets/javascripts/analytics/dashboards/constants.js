import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  MERGE_REQUEST_METRICS,
} from '~/analytics/shared/constants';

export const MAX_PANELS_LIMIT = 4;

export const UNITS = {
  COUNT: 'COUNT',
  DAYS: 'DAYS',
  PER_DAY: 'PER_DAY',
  PERCENT: 'PERCENT',
};

export const TABLE_METRICS = {
  [DORA_METRICS.DEPLOYMENT_FREQUENCY]: {
    label: s__('DORA4Metrics|Deployment Frequency'),
    units: UNITS.PER_DAY,
  },
  [DORA_METRICS.LEAD_TIME_FOR_CHANGES]: {
    label: s__('DORA4Metrics|Lead Time for Changes'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.TIME_TO_RESTORE_SERVICE]: {
    label: s__('DORA4Metrics|Time to Restore Service'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.CHANGE_FAILURE_RATE]: {
    label: s__('DORA4Metrics|Change Failure Rate'),
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
    label: s__('DORA4Metrics|New issues'),
    units: UNITS.COUNT,
  },
  [FLOW_METRICS.ISSUES_COMPLETED]: {
    label: s__('DORA4Metrics|Closed issues'),
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
  [VULNERABILITY_METRICS.CRITICAL]: {
    label: s__('DORA4Metrics|Critical Vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
  [VULNERABILITY_METRICS.HIGH]: {
    label: s__('DORA4Metrics|High Vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
};

export const METRICS_WITH_NO_TREND = [VULNERABILITY_METRICS.CRITICAL, VULNERABILITY_METRICS.HIGH];

export const DASHBOARD_TITLE = s__('DORA4Metrics|Value Streams Dashboard');
export const DASHBOARD_DESCRIPTION = s__(
  'DORA4Metrics|The Value Streams Dashboard allows all stakeholders from executives to individual contributors to identify trends, patterns, and opportunities for software development improvements.',
);
export const DASHBOARD_DOCS_LINK = helpPagePath('user/analytics/value_streams_dashboard');
export const DASHBOARD_DESCRIPTION_GROUP = s__('DORA4Metrics|Metrics comparison for %{name} group');
export const DASHBOARD_DESCRIPTION_PROJECT = s__(
  'DORA4Metrics|Metrics comparison for %{name} project',
);
export const DASHBOARD_NO_DATA = __('No data available');
export const DASHBOARD_LOADING_FAILURE = __('Failed to load');
export const DASHBOARD_NAMESPACE_LOAD_ERROR = s__(
  'DORA4Metrics|Failed to load comparison chart for Namespace: %{fullPath}',
);

export const CHART_GRADIENT = ['#499767', '#5252B5'];
export const CHART_GRADIENT_INVERTED = [...CHART_GRADIENT].reverse();
export const CHART_LOADING_FAILURE = s__('DORA4Metrics|Failed to load charts');

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

export const CLICK_METRIC_DRILLDOWN_LINK_ACTION = 'click_link';
