import ValueStreamDataSource from 'ee/analytics/analytics_dashboards/data_sources/value_stream';

describe('Value Stream Data Source', () => {
  let dataSource;
  let obj;

  const query = { filters: { exclude_metrics: [] } };
  const queryOverrides = { filters: { excludeMetrics: ['some metric'] } };
  const namespace = 'cool namespace';
  const title = 'fake title';

  beforeEach(() => {
    dataSource = new ValueStreamDataSource();
  });

  describe('fetch', () => {
    it('returns an object with the fields', async () => {
      obj = await dataSource.fetch({ namespace, title, query });

      expect(obj.namespace).toBe(namespace);
      expect(obj.title).toBe(title);
      expect(obj).toMatchObject({ filters: { excludeMetrics: [] } });
    });

    it('applies the queryOverrides over any relevant query parameters', async () => {
      obj = await dataSource.fetch({ namespace, query, queryOverrides });

      expect(obj).not.toMatchObject({ filters: { excludeMetrics: [] } });
      expect(obj).toMatchObject(queryOverrides);
    });
  });
});
