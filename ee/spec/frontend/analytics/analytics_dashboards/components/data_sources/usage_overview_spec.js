import {
  USAGE_OVERVIEW_METADATA,
  USAGE_OVERVIEW_IDENTIFIER_GROUPS,
  USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
  USAGE_OVERVIEW_IDENTIFIER_USERS,
  USAGE_OVERVIEW_IDENTIFIER_ISSUES,
  USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
  USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
} from '~/analytics/shared/constants';
import UsageOverviewDataSource, {
  prepareQuery,
  extractUsageMetrics,
  extractUsageNamespaceData,
} from 'ee/analytics/analytics_dashboards/data_sources/usage_overview';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  mockUsageMetricsQueryResponse,
  mockUsageNamespaceData,
  mockUsageMetrics,
  mockUsageMetricsNoData,
  mockUsageOverviewData,
} from '../../mock_data';

describe('Usage overview Data Source', () => {
  let obj;

  const namespace = 'some-group-path';
  const queryKeys = [USAGE_OVERVIEW_IDENTIFIER_GROUPS, USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS];
  const mockQuery = { filters: { include: queryKeys } };
  const { group: mockGroupUsageMetricsQueryResponse } = mockUsageMetricsQueryResponse;
  const identifiers = [
    USAGE_OVERVIEW_IDENTIFIER_GROUPS,
    USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
    USAGE_OVERVIEW_IDENTIFIER_USERS,
    USAGE_OVERVIEW_IDENTIFIER_ISSUES,
    USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
    USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
  ];

  describe('extractUsageMetrics', () => {
    it('returns an array of metrics', () => {
      expect(extractUsageMetrics(mockGroupUsageMetricsQueryResponse)).toEqual(mockUsageMetrics);
    });

    it('returns all the available metrics with their metadata', () => {
      const metrics = extractUsageMetrics(mockGroupUsageMetricsQueryResponse);

      metrics.forEach((metric) => {
        const { identifier, options } = metric;
        expect(identifiers.includes(identifier)).toBe(true);
        expect(metric.value).toBe(mockGroupUsageMetricsQueryResponse[identifier].count);
        expect(options).toBe(USAGE_OVERVIEW_METADATA[identifier].options);
      });
    });
  });

  describe('extractUsageNamespaceData', () => {
    it('returns the namespace data as expected', () => {
      expect(extractUsageNamespaceData(mockGroupUsageMetricsQueryResponse)).toEqual(
        mockUsageNamespaceData,
      );
    });
  });

  describe('prepareQuery', () => {
    const queryIncludeKeys = [
      'includeGroups',
      'includeProjects',
      'includeUsers',
      'includeIssues',
      'includeMergeRequests',
      'includePipelines',
    ];

    it('will return all the keys we can include', () => {
      expect(Object.keys(prepareQuery())).toEqual(queryIncludeKeys);
    });

    it('will return false for every key by default', () => {
      Object.values(prepareQuery()).forEach((res) => {
        expect(res).toBe(false);
      });
    });

    it('will set keys that are explicitly included to true', () => {
      const res = prepareQuery(queryKeys);

      expect(res).toEqual({
        includeGroups: true,
        includeIssues: false,
        includeProjects: false,
        includeUsers: false,
        includeMergeRequests: true,
        includePipelines: false,
      });
    });
  });

  describe('fetch', () => {
    let dataSource;
    beforeEach(() => {
      dataSource = new UsageOverviewDataSource();
    });

    it(`will request the namespace's usage overview metrics`, async () => {
      jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

      obj = await dataSource.fetch({ namespace, queryOverrides: mockQuery });

      expect(defaultClient.query).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            fullPath: 'some-group-path',
            startDate: expect.anything(),
            endDate: expect.anything(),
            includeGroups: true,
            includeMergeRequests: true,
            includeIssues: false,
            includeProjects: false,
            includePipelines: false,
            includeUsers: false,
          },
        }),
      );
    });

    it('will only request the specified metrics', async () => {
      jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

      obj = await dataSource.fetch({
        namespace,
        queryOverrides: { filters: { include: [USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS] } },
      });

      expect(defaultClient.query).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            fullPath: 'some-group-path',
            startDate: expect.anything(),
            endDate: expect.anything(),
            includeMergeRequests: true,
            includeGroups: false,
            includeIssues: false,
            includeProjects: false,
            includePipelines: false,
            includeUsers: false,
          },
        }),
      );
    });

    it.each`
      label                  | data                             | params
      ${'with no data'}      | ${{}}                            | ${{ namespace, queryOverrides: mockQuery }}
      ${'with no namespace'} | ${mockUsageMetricsQueryResponse} | ${{ namespace: null, queryOverrides: mockQuery }}
    `('$label returns the no data object', async ({ params }) => {
      jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

      obj = await dataSource.fetch(params);

      expect(obj).toMatchObject({ metrics: mockUsageMetricsNoData });
    });

    describe('with an error', () => {
      beforeEach(() => {
        jest.spyOn(defaultClient, 'query').mockRejectedValue();

        obj = dataSource.fetch({ namespace, queryOverrides: mockQuery });
      });

      it('returns the no data object', async () => {
        await expect(() => obj).rejects.toThrow('Failed to load usage overview data');
      });
    });

    describe('successfully completes', () => {
      beforeEach(async () => {
        jest
          .spyOn(defaultClient, 'query')
          .mockResolvedValue({ data: mockUsageMetricsQueryResponse });

        obj = await dataSource.fetch({ namespace, queryOverrides: mockQuery });
      });

      it('will fetch the usage overview data', () => {
        expect(obj).toMatchObject(mockUsageOverviewData);
      });
    });
  });
});
