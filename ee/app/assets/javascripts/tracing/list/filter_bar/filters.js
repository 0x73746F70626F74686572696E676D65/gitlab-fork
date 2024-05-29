import {
  filterToQueryObject,
  urlQueryToFilter,
  prepareTokens,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { TIME_RANGE_OPTIONS_VALUES, TIME_RANGE_OPTIONS } from '~/observability/constants';
import { isValidDate, getDayDifference } from '~/lib/utils/datetime_utility';

export const PERIOD_FILTER_TOKEN_TYPE = 'period';
export const SERVICE_NAME_FILTER_TOKEN_TYPE = 'service-name';
export const OPERATION_FILTER_TOKEN_TYPE = 'operation';
export const TRACE_ID_FILTER_TOKEN_TYPE = 'trace-id';
export const DURATION_MS_FILTER_TOKEN_TYPE = 'duration-ms';
export const ATTRIBUTE_FILTER_TOKEN_TYPE = 'attribute';
export const STATUS_FILTER_TOKEN_TYPE = 'status';

const DEFAULT_PERIOD_FILTER = [{ operator: '=', value: '1h' }];

const TIME_OPTIONS = [
  TIME_RANGE_OPTIONS_VALUES.FIVE_MIN,
  TIME_RANGE_OPTIONS_VALUES.FIFTEEN_MIN,
  TIME_RANGE_OPTIONS_VALUES.THIRTY_MIN,
  TIME_RANGE_OPTIONS_VALUES.ONE_HOUR,
  TIME_RANGE_OPTIONS_VALUES.FOUR_HOURS,
  TIME_RANGE_OPTIONS_VALUES.TWELVE_HOURS,
  TIME_RANGE_OPTIONS_VALUES.ONE_DAY,
  TIME_RANGE_OPTIONS_VALUES.ONE_WEEK,
];

const isValidPeriodValue = (value) => TIME_OPTIONS.includes(value);

export const PERIOD_FILTER_OPTIONS = TIME_RANGE_OPTIONS.filter(({ value }) =>
  isValidPeriodValue(value),
);

export const MAX_PERIOD_DAYS = 7;

/**
 * Returns true if the filter is a valid period filter. It can either be a string from a list of allowed values e.g. 5m, 1h
 * or a custom date range such as '2024-01-01 - 2024-01-02' ( note the date range must be less than 7 days)
 * */

function isValidPeriodFilter(filter = []) {
  if (filter.length !== 1 || !filter[0].value) return false;

  const { value } = filter[0];
  if (value.trim().indexOf(' ') < 0) {
    return isValidPeriodValue(value);
  }
  const dateParts = value.split(' - ');
  if (dateParts.length === 2) {
    const [start, end] = dateParts;
    const startDate = new Date(start);
    const endDate = new Date(end);
    return (
      isValidDate(startDate) &&
      isValidDate(endDate) &&
      getDayDifference(startDate, endDate) <= MAX_PERIOD_DAYS
    );
  }
  return false;
}

export function queryToFilterObj(query) {
  const filter = urlQueryToFilter(query, {
    filteredSearchTermKey: 'search',
    customOperators: [
      {
        operator: '>',
        prefix: 'gt',
      },
      {
        operator: '<',
        prefix: 'lt',
      },
    ],
  });
  const {
    period = undefined,
    service = undefined,
    operation = undefined,
    trace_id: traceId = undefined,
    durationMs = undefined,
    attribute = undefined,
    status = undefined,
  } = filter;
  const search = filter[FILTERED_SEARCH_TERM];
  return {
    attributes: {
      period: isValidPeriodFilter(period) ? period : DEFAULT_PERIOD_FILTER,
      service,
      operation,
      traceId,
      durationMs,
      search,
      attribute,
      status,
    },
  };
}

export function filterObjToQuery({ attributes }) {
  const attributesFilters = attributes
    ? filterToQueryObject(
        {
          period: attributes.period,
          service: attributes.service,
          operation: attributes.operation,
          trace_id: attributes.traceId,
          durationMs: attributes.durationMs,
          attribute: attributes.attribute,
          status: attributes.status,
          [FILTERED_SEARCH_TERM]: attributes.search,
        },
        {
          filteredSearchTermKey: 'search',
          customOperators: [
            {
              operator: '>',
              prefix: 'gt',
              applyOnlyToKey: 'durationMs',
            },
            {
              operator: '<',
              prefix: 'lt',
              applyOnlyToKey: 'durationMs',
            },
          ],
        },
      )
    : {};
  return {
    ...attributesFilters,
  };
}

export function filterObjToFilterToken(filters) {
  return prepareTokens({
    [PERIOD_FILTER_TOKEN_TYPE]: filters.period,
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: filters.service,
    [OPERATION_FILTER_TOKEN_TYPE]: filters.operation,
    [TRACE_ID_FILTER_TOKEN_TYPE]: filters.traceId,
    [DURATION_MS_FILTER_TOKEN_TYPE]: filters.durationMs,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: filters.attribute,
    [FILTERED_SEARCH_TERM]: filters.search,
    [STATUS_FILTER_TOKEN_TYPE]: filters.status,
  });
}

export function filterTokensToFilterObj(tokens) {
  const {
    [SERVICE_NAME_FILTER_TOKEN_TYPE]: service,
    [PERIOD_FILTER_TOKEN_TYPE]: period = DEFAULT_PERIOD_FILTER,
    [OPERATION_FILTER_TOKEN_TYPE]: operation,
    [TRACE_ID_FILTER_TOKEN_TYPE]: traceId,
    [DURATION_MS_FILTER_TOKEN_TYPE]: durationMs,
    [ATTRIBUTE_FILTER_TOKEN_TYPE]: attribute,
    [FILTERED_SEARCH_TERM]: search,
    [STATUS_FILTER_TOKEN_TYPE]: status,
  } = processFilters(tokens);

  return {
    service,
    period,
    operation,
    traceId,
    durationMs,
    attribute,
    search,
    status,
  };
}
