import fetch from 'ee/analytics/analytics_dashboards/data_sources/value_stream';

describe('Value Stream Data Source', () => {
  let obj;

  const query = { filters: { exclude_metrics: [] } };
  const queryOverrides = { filters: { excludeMetrics: ['some metric'] } };
  const namespace = 'cool namespace';
  const title = 'fake title';

  describe('fetch', () => {
    it('returns an object with the fields', async () => {
      obj = await fetch({ namespace, title, query });

      expect(obj.namespace).toBe(namespace);
      expect(obj.title).toBe(title);
      expect(obj).toMatchObject({ filters: { excludeMetrics: [] } });
    });

    it('applies the queryOverrides over any relevant query parameters', async () => {
      obj = await fetch({ namespace, query, queryOverrides });

      expect(obj).not.toMatchObject({ filters: { excludeMetrics: [] } });
      expect(obj).toMatchObject(queryOverrides);
    });
  });
});
