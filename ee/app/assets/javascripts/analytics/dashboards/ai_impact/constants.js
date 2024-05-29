import { pick } from 'lodash';
import { s__ } from '~/locale';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  AI_METRICS,
} from '~/analytics/shared/constants';

import { UNITS, TABLE_METRICS as VSD_TABLE_METRICS } from '../constants';

export const SUPPORTED_FLOW_METRICS = [FLOW_METRICS.CYCLE_TIME, FLOW_METRICS.LEAD_TIME];

export const SUPPORTED_DORA_METRICS = [
  DORA_METRICS.DEPLOYMENT_FREQUENCY,
  DORA_METRICS.CHANGE_FAILURE_RATE,
];

export const SUPPORTED_VULNERABILITY_METRICS = [VULNERABILITY_METRICS.CRITICAL];

export const SUPPORTED_AI_METRICS = [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE];

// Code suggestions usage only started being tracked April 4, 2024
// https://gitlab.com/gitlab-org/gitlab/-/issues/456108
export const CODE_SUGGESTIONS_START_DATE = new Date('2024-04-04');

export const AI_IMPACT_TABLE_METRICS = {
  ...pick(VSD_TABLE_METRICS, [
    ...SUPPORTED_FLOW_METRICS,
    ...SUPPORTED_DORA_METRICS,
    ...SUPPORTED_VULNERABILITY_METRICS,
  ]),
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Code Suggestions usage'),
    units: UNITS.PERCENT,
  },
};
