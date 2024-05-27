import { mockDoraMetricsResponseData } from 'ee_jest/analytics/dashboards/mock_data';
import DoraMetricsOverTimeDataSource from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { LAST_WEEK, LAST_180_DAYS } from 'ee/dora/components/static_data/shared';

describe('Dora Metrics Over Time Data Source', () => {
  let dataSource;
  let res;

  const query = { metric: 'lead_time_for_changes', date_range: LAST_180_DAYS };
  const namespace = 'cool namespace';

  const mockResolvedQuery = (dora = mockDoraMetricsResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data: { group: { dora } } });

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  beforeEach(() => {
    dataSource = new DoraMetricsOverTimeDataSource();
  });

  describe('fetch', () => {
    describe('default', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await dataSource.fetch({ namespace, query });
      });

      it('returns a single value', () => {
        expect(res).toBe('0.2721');
      });

      it('correctly applies query parameters', () => {
        expectQueryWithVariables({
          startDate: new Date('2020-01-09'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool namespace',
          interval: 'ALL',
        });
      });
    });

    describe('queryOverrides', () => {
      it('can override the date range', async () => {
        mockResolvedQuery();
        res = await dataSource.fetch({
          namespace,
          query,
          queryOverrides: { date_range: LAST_WEEK },
        });

        expectQueryWithVariables({
          startDate: new Date('2020-06-30'),
          endDate: new Date('2020-07-07'),
          fullPath: 'cool namespace',
          interval: 'ALL',
        });
      });
    });
  });
});
