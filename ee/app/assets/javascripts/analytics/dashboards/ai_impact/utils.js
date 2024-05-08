import { __, sprintf } from '~/locale';
import {
  getStartOfDay,
  dateAtFirstDayOfMonth,
  nMonthsBefore,
  monthInWords,
  nSecondsBefore,
} from '~/lib/utils/datetime_utility';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import { formatMetric, percentChange, isMetricInTimePeriods } from '../utils';
import { AI_IMPACT_TABLE_METRICS } from './constants';

const getColumnKeyForMonth = (monthsAgo) => `${monthsAgo}-months-ago`;
const getStartOfMonth = (now) => dateAtFirstDayOfMonth(getStartOfDay(now));

/**
 * Generates the time period columns, from This month -> 5 months ago.
 *
 * @param {Date} now Current date
 * @returns {Array} Tuple of time periods
 */
export const generateDateRanges = (now) => {
  const currentMonth = {
    key: 'this-month',
    label: monthInWords(now, true),
    start: getStartOfMonth(now),
    end: now,
    thClass: 'gl-w-1/10',
  };

  return [1, 2, 3, 4, 5].reduce(
    (acc, nMonth) => {
      const thisMonthStart = getStartOfMonth(now);
      const start = nMonthsBefore(thisMonthStart, nMonth);
      const end = nSecondsBefore(nMonthsBefore(thisMonthStart, nMonth - 1), 1);
      return [
        {
          key: getColumnKeyForMonth(nMonth),
          label: monthInWords(start, true),
          start,
          end,
          thClass: 'gl-w-1/10',
        },
        ...acc,
      ];
    },
    [currentMonth],
  );
};

/**
 * Generates all the table columns based on the given date.
 *
 * @param {Date} now
 * @returns {Array} The list of columns
 */
export const generateTableColumns = (now) => [
  {
    key: 'metric',
    label: __('Metric'),
    thClass: 'gl-w-2/10',
  },
  ...generateDateRanges(now),
  {
    key: 'change',
    label: sprintf(__('Change (%%)')),
    description: __('Past 6 Months'),
    thClass: 'gl-w-2/10',
  },
];

/**
 * Creates the table rows filled with blank data. Once the data has loaded,
 * it can be filled into the returned skeleton using `mergeTableData`.
 *
 * @returns {Array} array of data-less table rows
 */
export const generateSkeletonTableData = () =>
  Object.entries(AI_IMPACT_TABLE_METRICS).map(([identifier, { label, invertTrendColor }]) => ({
    metric: { identifier, value: label },
    invertTrendColor,
  }));

/**
 * Takes N time periods for a single metric and generates the row for the table.
 *
 * @param {String} identifier - ID of the metric to create a table row for.
 * @param {String} units - The type of units used for this metric (ex. days, /day, count)
 * @param {Array} timePeriods - Array of the metrics for different time periods
 * @returns {Object} The metric data formatted as a table row.
 */
const buildTableRow = ({ identifier, units, timePeriods }) => {
  const row = timePeriods.reduce((acc, timePeriod) => {
    const metric = timePeriod[identifier];
    return Object.assign(acc, {
      [timePeriod.key]: {
        value: metric?.value !== '-' ? formatMetric(metric.value, units) : '-',
        tooltip: metric?.tooltip,
      },
    });
  }, {});

  const firstMonth = timePeriods.find((timePeriod) => timePeriod.key === getColumnKeyForMonth(1));
  const lastMonth = timePeriods.find((timePeriod) => timePeriod.key === getColumnKeyForMonth(5));
  row.change = {
    value: percentChange({
      current: firstMonth[identifier]?.value !== '-' ? firstMonth[identifier].value : 0,
      previous: lastMonth[identifier]?.value !== '-' ? lastMonth[identifier].value : 0,
    }),
  };

  return row;
};

/**
 * Takes N time periods of metrics and formats the data to be displayed in the table.
 *
 * @param {Array} timePeriods - Array of metrics for different time periods
 * @returns {Object} object containing the same data, formatted for the table
 */
export const generateTableRows = (timePeriods) =>
  Object.entries(AI_IMPACT_TABLE_METRICS).reduce((acc, [identifier, { units }]) => {
    if (!isMetricInTimePeriods(identifier, timePeriods)) return acc;

    return Object.assign(acc, {
      [identifier]: buildTableRow({
        identifier,
        units,
        timePeriods,
      }),
    });
  }, {});

/**
 * Calculates the percentage of code contributors that used the GitLab Duo Code Suggestions features.
 *
 * @param {number} codeSuggestionsContributorsCount - Number of code contributors that used GitLab Duo Code Suggestions features.
 * @param {number} codeContributorsCount - Number of code contributors
 * @returns {number|null} - Percentage of code contributors that used the GitLab Duo Code Suggestions features or null if either count is invalid
 */
export const calculateCodeSuggestionsUsageRate = ({
  codeSuggestionsContributorsCount,
  codeContributorsCount,
} = {}) => {
  const hasValidCounts =
    isPositiveInteger(codeSuggestionsContributorsCount) && codeContributorsCount > 0;

  if (!hasValidCounts) return null;

  return (codeSuggestionsContributorsCount / codeContributorsCount) * 100;
};
