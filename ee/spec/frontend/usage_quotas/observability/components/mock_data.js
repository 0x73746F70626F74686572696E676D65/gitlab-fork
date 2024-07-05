export const mockData = {
  events: {
    6: {
      start_ts: 1717200000000000000,
      end_ts: 1719705600000000000,
      aggregated_total: 132,
      aggregated_per_feature: {
        metrics: 40,
        logs: 32,
        tracing: 60,
      },
      data: {
        metrics: [[1719446400000000000, 100]],
      },
      data_breakdown: 'daily',
      data_unit: '',
    },
  },
  storage: {
    6: {
      start_ts: 1717200000000000000,
      end_ts: 1719705600000000000,
      aggregated_total: 58476,
      aggregated_per_feature: {
        metrics: 15000,
        logs: 15000,
        tracing: 28476,
      },
      data: {
        metrics: [[1719446400000000000, 58476]],
      },
      data_breakdown: 'daily',
      data_unit: 'bytes',
    },
  },
};
