import { __, s__, sprintf } from '~/locale';
import dateFormat from '~/lib/dateformat';
import { dateFormats, AI_METRICS } from '~/analytics/shared/constants';
import { calculateCodeSuggestionsUsageRate } from './utils';
import { CODE_SUGGESTIONS_START_DATE } from './constants';

/**
 * @typedef {Object} TableMetric
 * @property {String} identifier - Identifier for the specified metric
 * @property {Number|'-'} value - Display friendly value
 * @property {String} tooltip - Actual usage rate values to be displayed in tooltip
 */

/**
 * @typedef {Object} AiMetricItem
 * @property {Date} timePeriodEnd - The end date of the time period used to fetch the metric data
 * @property {Integer} codeContributorsCount - Number of code contributors
 * @property {Integer} codeSuggestionsContributorsCount - Number of code contributors who used GitLab Duo Code Suggestions features
 */

/**
 * @typedef {Object} AiMetricResponseItem
 * @property {TableMetric} code_suggestions_usage_rate
 */

/**
 * Takes the raw `aiMetrics` graphql response and prepares the data for display
 * in the table.
 *
 * @param {AiMetricItem} data
 * @returns {AiMetricResponseItem} AI metrics ready for rendering in the dashboard
 */
export const extractGraphqlAiData = ({
  timePeriodEnd,
  codeContributorsCount = null,
  codeSuggestionsContributorsCount = null,
} = {}) => {
  const codeSuggestionsUsageRate = calculateCodeSuggestionsUsageRate({
    codeSuggestionsContributorsCount,
    codeContributorsCount,
  });

  let tooltip = __('No data');
  if (timePeriodEnd < CODE_SUGGESTIONS_START_DATE) {
    tooltip = sprintf(
      s__(
        'AiImpactAnalytics|Usage rate for Code Suggestions is calculated with data starting on %{startDate}',
      ),
      { startDate: dateFormat(CODE_SUGGESTIONS_START_DATE, dateFormats.defaultDate) },
    );
  } else if (codeSuggestionsUsageRate !== null) {
    tooltip = `${codeSuggestionsContributorsCount}/${codeContributorsCount}`;
  }

  return {
    [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
      identifier: AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
      value: codeSuggestionsUsageRate ?? '-',
      tooltip,
    },
  };
};
