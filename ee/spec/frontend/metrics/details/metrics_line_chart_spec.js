import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import { nextTick } from 'vue';
import MetricsLineChart from 'ee/metrics/details/metrics_line_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MetricsLineChart', () => {
  const mockData = [
    {
      name: 'container_cpu_usage_seconds_total',
      type: 'Gauge',
      unit: 's',
      attributes: { foo: 'bar', baz: 'abc' },
      values: [
        [`${1700118610000 * 1e6}`, '0.25595267476015443'],
        [`${1700118660000 * 1e6}`, '0.1881374588830907'],
        [`${1700118720000 * 1e6}`, '0.28915416028993485'],
      ],
    },
    {
      name: 'container_cpu_usage_seconds_total',
      type: 'Gauge',
      unit: 's',
      attributes: { foo: 'bar', baz: 'def' },
      values: [
        [`${1700119020000 * 1e6}`, '1.2658100987444416'],
        [`${1700119080000 * 1e6}`, '3.0604918827864345'],
        [`${1700119140000 * 1e6}`, '3.0205790879854124'],
      ],
    },
  ];

  let wrapper;

  const mountComponent = ({ data = mockData, loading = false, cancelled = false } = {}) => {
    wrapper = shallowMountExtended(MetricsLineChart, {
      propsData: {
        metricData: data,
        loading,
        cancelled,
      },
    });
  };

  const findChart = () => wrapper.findComponent(GlLineChart);

  beforeEach(() => {
    mountComponent();
  });

  it('renders GlChart component', () => {
    expect(findChart().exists()).toBe(true);
  });

  describe('chart data', () => {
    it('passes chart data to GlLineChart via props', () => {
      expect(findChart().props('data')).toEqual([
        {
          data: [
            [
              mockData[0].values[0][0] / 1e6,
              parseFloat(mockData[0].values[0][1]),
              { ...mockData[0].attributes },
            ],
            [
              mockData[0].values[1][0] / 1e6,
              parseFloat(mockData[0].values[1][1]),
              { ...mockData[0].attributes },
            ],
            [
              mockData[0].values[2][0] / 1e6,
              parseFloat(mockData[0].values[2][1]),
              { ...mockData[0].attributes },
            ],
          ],
          name: 'foo: bar, baz: abc',
        },
        {
          data: [
            [
              mockData[1].values[0][0] / 1e6,
              parseFloat(mockData[1].values[0][1]),
              { ...mockData[1].attributes },
            ],
            [
              mockData[1].values[1][0] / 1e6,
              parseFloat(mockData[1].values[1][1]),
              { ...mockData[1].attributes },
            ],
            [
              mockData[1].values[2][0] / 1e6,
              parseFloat(mockData[1].values[2][1]),
              { ...mockData[1].attributes },
            ],
          ],
          name: 'foo: bar, baz: def',
        },
      ]);
    });
  });

  describe('chart options', () => {
    it('adds the unit to the y axis label if available in the data', () => {
      expect(findChart().props('option').yAxis.name).toBe('Value (s)');
    });

    it('does not add any unit to the y axis label if not in the data', () => {
      const data = [{ ...mockData[0], unit: '' }];
      mountComponent({ data });
      expect(findChart().props('option').yAxis.name).toBe('Value');
    });
  });

  describe('tooltip', () => {
    const mockTooltipData = [
      {
        data: [
          mockData[0].values[0][0] / 1e6,
          mockData[0].values[0][1],
          { ...mockData[0].attributes },
        ],
        name: 'series-0',
        color: 'color-0',
        seriesId: 'id-0',
      },
      {
        data: [
          mockData[1].values[0][0] / 1e6,
          mockData[1].values[0][1],
          { ...mockData[1].attributes },
        ],
        name: 'series-1',
        color: 'color-1',
        seriesId: 'id-1',
      },
    ];

    const mockFormatTooltipText = async (data = []) => {
      findChart().props('formatTooltipText')({ seriesData: data });
      await nextTick();
    };

    const getTooltipTitle = () => findChart().find(`[data-testid="metric-tooltip-title"]`);

    beforeEach(async () => {
      await mockFormatTooltipText(mockTooltipData);
    });

    describe('title', () => {
      it('sets the title to the x data point of the first series', () => {
        expect(getTooltipTitle().text()).toBe('Nov 16, 2023 7:10:10');
      });

      it('handles empty data', async () => {
        await mockFormatTooltipText();

        expect(getTooltipTitle().text()).toBe('');
      });
    });

    describe('content', () => {
      const expectedLabels = [
        ['foo: bar', 'baz: abc'],
        ['foo: bar', 'baz: def'],
      ];

      it('renders content for each time series', () => {
        const content = findChart().findAll(`[data-testid="metric-tooltip-content"]`);
        expect(content).toHaveLength(mockTooltipData.length);
        content.wrappers.forEach((w, i) => {
          const timeseries = mockTooltipData[i];

          expect(w.find(`[data-testid="metric-tooltip-value"]`).text()).toBe(
            parseFloat(timeseries.data[1]).toFixed(3),
          );

          const label = w.findComponent(GlChartSeriesLabel);
          expect(label.props('color')).toBe(timeseries.color);

          const attributeContainers = label.findAll('div');
          expect(attributeContainers).toHaveLength(Object.entries(timeseries.data[2]).length);
          attributeContainers.wrappers.forEach((c, j) => {
            expect(c.text()).toBe(expectedLabels[i][j]);
          });
        });
      });
    });
  });
  describe('loading', () => {
    it('changes the opacity when loading', () => {
      mountComponent({ loading: true });

      expect(findChart().classes()).toContain('gl-opacity-3');
    });

    it('does not change the opacity when not loading', () => {
      mountComponent({ loading: false });

      expect(findChart().classes()).not.toContain('gl-opacity-3');
    });
  });

  describe('cancelled', () => {
    const cancelledText = 'Metrics search has been cancelled.';

    describe('when cancelled=true', () => {
      beforeEach(() => {
        mountComponent({ cancelled: true });
      });

      it('overrides the opacity', () => {
        expect(findChart().classes()).toContain('gl-opacity-3');
      });

      it('shows the cancelled messaged', () => {
        expect(wrapper.text()).toContain(cancelledText);
      });
    });

    describe('when cancelled=false', () => {
      beforeEach(() => {
        mountComponent({ cancelled: false });
      });

      it('overrides the opacity', () => {
        expect(findChart().classes()).not.toContain('gl-opacity-3');
      });

      it('shows the cancelled messaged', () => {
        expect(wrapper.text()).not.toContain(cancelledText);
      });
    });
  });
});
