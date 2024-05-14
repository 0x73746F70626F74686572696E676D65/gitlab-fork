import { CubeApi, HttpTransport } from '@cubejs-client/core';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { pikadayToString } from '~/lib/utils/datetime_utility';
import csrf from '~/lib/utils/csrf';
import { joinPaths } from '~/lib/utils/url_utility';
import {
  EVENTS_TABLE_NAME,
  RETURNING_USERS_TABLE_NAME,
  SESSIONS_TABLE_NAME,
  TRACKED_EVENTS_KEY,
} from 'ee/analytics/analytics_dashboards/constants';

// This can be any value because the cube proxy adds the real API token.
const CUBE_API_TOKEN = '1';
const PRODUCT_ANALYTICS_CUBE_PROXY = '/api/v4/projects/:id/product_analytics/request';

// Filter measurement types must be lowercase
export const DATE_RANGE_FILTER_DIMENSIONS = {
  [TRACKED_EVENTS_KEY]: `${EVENTS_TABLE_NAME}.derivedTstamp`,
  sessions: `${SESSIONS_TABLE_NAME}.startAt`,
  returningusers: `${RETURNING_USERS_TABLE_NAME}.first_timestamp`,
};

const convertToCommonChartFormat = (resultSet) => {
  const seriesNames = resultSet.seriesNames();
  const pivot = resultSet.chartPivot();

  return seriesNames.map((series) => ({
    name: series.title,
    data: pivot.map((p) => [p.x, p[series.key]]),
  }));
};

const findLinkOptions = (key, visualizationOptions) => {
  const links = visualizationOptions?.links;
  if (!links) return null;

  const normalizedLinks = links.map(({ text, href }) => ({ text, href: [href].flat() }));
  return normalizedLinks.find(({ text, href }) => [text, ...href].includes(key));
};

export const convertToTableFormat = (resultSet, _query, visualizationOptions) => {
  const columns = resultSet.tableColumns();
  const rows = resultSet.tablePivot();

  const columnTitles = Object.fromEntries(
    columns.map((column) => [column.key, convertToSnakeCase(column.shortTitle)]),
  );

  return rows.map((row) => {
    return Object.fromEntries(
      Object.entries(row)
        .map(([key, value]) => {
          const linkOptions = findLinkOptions(key, visualizationOptions);

          if (key === linkOptions?.text) {
            return [
              columnTitles[key],
              {
                text: value,
                href: joinPaths(...linkOptions.href.map((hrefPart) => row[hrefPart])),
              },
            ];
          }

          if (linkOptions?.href.includes(key)) {
            // Skipped because the href gets rendered as part of the link text column.
            return null;
          }

          return [columnTitles[key], value];
        })
        .filter(Boolean),
    );
  });
};

const convertToSingleValue = (resultSet, query) => {
  const [measure] = query?.measures ?? [];
  const [row] = resultSet.rawData();

  if (!row) {
    return 0;
  }

  return row[measure] ?? 0;
};

const getQueryTableKey = (query) => query.measures[0].split('.')[0].toLowerCase();

const buildDateRangeFilter = (query, queryOverrides, { startDate, endDate }) => {
  if (!startDate && !endDate) return {};

  const tableKey = getQueryTableKey(query);

  return {
    filters: [
      ...(query.filters ?? []),
      ...(queryOverrides.filters ?? []),
      {
        member: DATE_RANGE_FILTER_DIMENSIONS[tableKey],
        operator: 'inDateRange',
        values: [pikadayToString(startDate), pikadayToString(endDate)],
      },
    ],
  };
};

const buildAnonUsersFilter = (query, queryOverrides, { filterAnonUsers }) => {
  if (!filterAnonUsers) return {};

  // knownUsers is only applicable on tracked events
  if (getQueryTableKey(query) !== TRACKED_EVENTS_KEY) return {};

  return {
    segments: [
      ...(query.segments ?? []),
      ...(queryOverrides.segments ?? []),
      'TrackedEvents.knownUsers',
    ],
  };
};

const buildCubeQuery = (query, queryOverrides, filters) => ({
  ...query,
  ...queryOverrides,
  ...buildDateRangeFilter(query, queryOverrides, filters),
  ...buildAnonUsersFilter(query, queryOverrides, filters),
});

const VISUALIZATION_PARSERS = {
  LineChart: convertToCommonChartFormat,
  ColumnChart: convertToCommonChartFormat,
  DataTable: convertToTableFormat,
  SingleStat: convertToSingleValue,
};

export const createCubeApi = (projectId) =>
  new CubeApi(CUBE_API_TOKEN, {
    transport: new HttpTransport({
      apiUrl: PRODUCT_ANALYTICS_CUBE_PROXY.replace(':id', projectId),
      method: 'POST',
      headers: {
        [csrf.headerKey]: csrf.token,
        'X-Requested-With': 'XMLHttpRequest',
      },
      credentials: 'same-origin',
    }),
  });

export default class CubeAnalyticsDataSource {
  #cubeApi;

  constructor({ projectId }) {
    this.#cubeApi = createCubeApi(projectId);
  }

  async fetch({
    visualizationType,
    visualizationOptions,
    query,
    queryOverrides = {},
    filters = {},
  }) {
    const userQuery = buildCubeQuery(query, queryOverrides, filters);
    const request = this.#cubeApi.load(userQuery, {
      castNumerics: true,
    });

    return request.then((resultSet) =>
      VISUALIZATION_PARSERS[visualizationType](resultSet, userQuery, visualizationOptions),
    );
  }
}
