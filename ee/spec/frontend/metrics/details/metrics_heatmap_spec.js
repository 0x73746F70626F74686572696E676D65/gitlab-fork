import { GlHeatmap } from '@gitlab/ui/dist/charts';
import MetricsHeatmap from 'ee/metrics/details/metrics_heatmap.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MetricsHeatmap', () => {
  const mockData = [
    {
      name: 'test_name',
      description: 'randomDescription',
      unit: 'randomUnit',
      type: 'Histogram',
      data: [
        {
          bucketsHash: 123,
          buckets: ['A', 'B', 'C'],
          distribution: [
            [
              ['1707098160000000000', '2.123'],
              ['1707098220000000000', '6.123'],
              ['1707098280000000000', '2.123'],
            ],
            [
              ['1707098160000000000', '4.456'],
              ['1707098220000000000', '5.456'],
              ['1707098280000000000', '2.456'],
            ],
            [
              ['1707098160000000000', '2.345'],
              ['1707098220000000000', '4.345'],
              ['1707098280000000000', '5.345'],
            ],
          ],
        },
      ],
    },
  ];

  let wrapper;

  const mountComponent = ({ metricData = mockData, loading = false, cancelled = false } = {}) => {
    wrapper = shallowMountExtended(MetricsHeatmap, {
      propsData: {
        metricData,
        loading,
        cancelled,
      },
    });
  };

  const findHeatmap = () => wrapper.findComponent(GlHeatmap);

  beforeEach(() => {
    mountComponent();
  });

  it('renders GlHeatmap component', () => {
    expect(findHeatmap().exists()).toBe(true);
  });

  describe('chart data', () => {
    it('passes chart data to GlHeatmap via props', () => {
      expect(findHeatmap().props('dataSeries')).toEqual([
        [0, 0, 2.123],
        [1, 0, 6.123],
        [2, 0, 2.123],
        [0, 1, 4.456],
        [1, 1, 5.456],
        [2, 1, 2.456],
        [0, 2, 2.345],
        [1, 2, 4.345],
        [2, 2, 5.345],
      ]);
    });
  });

  it('sets the x labels to formatted timestamps', () => {
    expect(findHeatmap().props('xAxisLabels')).toEqual(['01:56', '01:57', '01:58']);
  });

  it('sets the y labels to buckets', () => {
    expect(findHeatmap().props('yAxisLabels')).toEqual(['A', 'B', 'C']);
  });

  it('overrides options to enable the default tooltip', () => {
    expect(findHeatmap().props('options')).toEqual({
      tooltip: {},
      xAxis: { axisPointer: { show: false } },
    });
  });

  describe('loading', () => {
    it('changes the opacity when loading', () => {
      mountComponent({ loading: true });

      expect(findHeatmap().classes()).toContain('gl-opacity-3');
    });

    it('does not change the opacity when not loading', () => {
      mountComponent({ loading: false });

      expect(findHeatmap().classes()).not.toContain('gl-opacity-3');
    });
  });

  describe('cancelled', () => {
    const cancelledText = 'Metrics search has been cancelled.';

    describe('when cancelled=true', () => {
      beforeEach(() => {
        mountComponent({ cancelled: true });
      });

      it('overrides the opacity', () => {
        expect(findHeatmap().classes()).toContain('gl-opacity-3');
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
        expect(findHeatmap().classes()).not.toContain('gl-opacity-3');
      });

      it('shows the cancelled messaged', () => {
        expect(wrapper.text()).not.toContain(cancelledText);
      });
    });
  });

  it.each([
    {
      metricData: [],
    },
    {
      metricData: [{}],
    },
    {
      metricData: [{ data: [] }],
    },
    {
      metricData: [{ data: [{ distribution: [] }] }],
    },
  ])('handles missing data gracefully', (props) => {
    mountComponent(props);

    expect(findHeatmap().props('dataSeries')).toEqual([]);
    expect(findHeatmap().props('xAxisLabels')).toEqual([]);
    expect(findHeatmap().props('yAxisLabels')).toEqual([]);
  });
});
