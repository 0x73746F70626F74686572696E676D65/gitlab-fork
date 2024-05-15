import { GlSkeletonLoader } from '@gitlab/ui';
import { GlLineChart } from '@gitlab/ui/dist/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LogsVolume from 'ee/logs/list/logs_volume.vue';
import { stubComponent } from 'helpers/stub_component';

describe('LogsVolume', () => {
  const MOCK_LOGS_COUNT = [
    {
      time: 1713519360000000000,
      counts: {
        13: 10,
        9: 20,
      },
    },
    {
      time: 1713545280000000000,
      counts: {
        13: 5,
        9: 6,
      },
    },
    {
      time: 1713571200000000000,
      counts: {
        13: 30,
        9: 35,
      },
    },
  ];

  let wrapper;

  const mountComponent = ({
    loading = false,
    logsCount = MOCK_LOGS_COUNT,
    height = 123,
    mockTooltipParams = {},
  } = {}) => {
    const mockChartWithTooltip = {
      data() {
        return { mockTooltipParams };
      },
      template: `<div><slot name="tooltip-title" :params="mockTooltipParams"></slot></div>`,
    };
    wrapper = shallowMountExtended(LogsVolume, {
      propsData: {
        loading,
        logsCount,
        height,
      },
      stubs: {
        GlLineChart: stubComponent(GlLineChart, mockChartWithTooltip),
      },
    });
  };

  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findChart = () => wrapper.findComponent(GlLineChart);

  it('displays a skeleton loader when loading', () => {
    mountComponent({
      loading: true,
    });

    expect(findSkeleton().exists()).toBe(true);
    expect(findChart().exists()).toBe(false);
  });

  it('displays a line chart if logs data exists', () => {
    mountComponent();

    expect(findChart().exists()).toBe(true);
    expect(findSkeleton().exists()).toBe(false);
  });

  it('does not diplay a chart if logsCounts is empty', () => {
    mountComponent({
      logsCount: [],
    });
    expect(findChart().exists()).toBe(false);
  });

  it('does not diplay a chart if counts are empty', () => {
    mountComponent({
      logsCount: [
        { time: 1715341043520000000, counts: {} },
        { time: 1715341069440000000, counts: {} },
        { time: 1715341095360000000, counts: {} },
        { time: 1715341121280000000, counts: {} },
      ],
    });
    expect(findChart().exists()).toBe(false);
  });

  it('sets the height prop in the chart', () => {
    const height = 123;
    mountComponent({}, height);
    expect(findChart().props('height')).toBe(height);
  });

  it('sets the data prop in the chart', () => {
    mountComponent();
    expect(findChart().props('data')).toEqual([
      {
        data: [
          [1713519360000, 20],
          [1713545280000, 6],
          [1713571200000, 35],
        ],
        itemStyle: { color: '#428fdc' },
        lineStyle: { color: '#428fdc' },
        name: 'info',
      },
      {
        data: [
          [1713519360000, 10],
          [1713545280000, 5],
          [1713571200000, 30],
        ],
        itemStyle: { color: '#e9be74' },
        lineStyle: { color: '#e9be74' },
        name: 'warn',
      },
    ]);
  });

  it('renders the tooltip title as formatted date', () => {
    mountComponent({
      mockTooltipParams: { seriesData: [{ data: [[new Date('05-05-2024 15:52:32'), 1]] }] },
    });
    expect(findChart().text()).toBe('May 5, 2024 3:52pm UTC');
  });
});
