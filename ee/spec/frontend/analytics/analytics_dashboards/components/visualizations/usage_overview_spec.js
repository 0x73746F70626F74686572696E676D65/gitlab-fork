import { GlAvatar, GlIcon } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/dist/charts';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import UsageOverview from 'ee/analytics/analytics_dashboards/components/visualizations/usage_overview.vue';
import { mockUsageOverviewData, mockUsageMetrics, mockUsageMetricsNoData } from '../../mock_data';

describe('Usage Overview Visualization', () => {
  let wrapper;
  const defaultProps = { data: mockUsageOverviewData, options: {} };
  const defaultProvide = { overviewCountsAggregationEnabled: true };

  const findNamespaceTile = () => wrapper.findByTestId('usage-overview-namespace');
  const findNamespaceAvatar = () => findNamespaceTile().findComponent(GlAvatar);
  const findNamespaceVisibilityIcon = () => findNamespaceTile().findComponent(GlIcon);

  const findMetrics = () => wrapper.findAllComponents(GlSingleStat);

  const findMetricProperty = (property, idx) => wrapper.findAllByTestId(property).at(idx);
  const findMetricTitle = (idx) => findMetricProperty('title-text', idx);
  const findMetricIcon = (idx) => findMetricProperty('title-icon', idx);
  const findMetricValue = (idx) => findMetricProperty('displayValue', idx);

  const createWrapper = ({ props = defaultProps, provide = defaultProvide } = {}) => {
    wrapper = mountExtended(UsageOverview, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        overviewCountsAggregationEnabled: true,
        ...provide,
      },
      propsData: {
        data: props.data,
        options: props.options,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('namespace', () => {
      it("should render namespace's full name", () => {
        expect(wrapper.findByText('GitLab Org').exists()).toBe(true);
      });

      it('should render namespace type', () => {
        expect(wrapper.findByText('Group').exists()).toBe(true);
      });

      it('should render avatar', () => {
        expect(findNamespaceAvatar().props()).toMatchObject({
          entityName: 'GitLab Org',
          entityId: 225,
          src: '/avatar.png',
          shape: 'rect',
          fallbackOnError: true,
          size: 48,
        });
      });

      it('should render visibility level icon', () => {
        const tooltip = getBinding(findNamespaceVisibilityIcon().element, 'gl-tooltip');

        expect(findNamespaceVisibilityIcon().exists()).toBe(true);
        expect(tooltip).toBeDefined();
        expect(findNamespaceVisibilityIcon().props('name')).toBe('earth');
        expect(findNamespaceVisibilityIcon().attributes('title')).toBe(
          'Public - The group and any public projects can be viewed without any authentication.',
        );
      });

      it('does not emit `set-alerts', () => {
        expect(wrapper.emitted('set-alerts')).toBeUndefined();
      });
    });

    describe('metrics', () => {
      it('should render each metric', () => {
        expect(findMetrics()).toHaveLength(mockUsageMetrics.length);
      });

      it('should render each metric as a single stat', () => {
        mockUsageMetrics.forEach(({ value, options }, idx) => {
          expect(findMetricTitle(idx).text()).toBe(options.title);
          expect(findMetricIcon(idx).props('name')).toBe(options.titleIcon);
          expect(findMetricValue(idx).text()).toBe(String(value));
        });
      });

      it('emits `showTooltip` with the latest metric.recordedAt as the last updated time', () => {
        expect(wrapper.emitted('showTooltip')).toHaveLength(1);
        expect(wrapper.emitted('showTooltip')[0][0]).toEqual(
          'Statistics on namespace usage. Usage data is a cumulative count, and updated monthly. Last updated: 2023-11-27 11:59 PM',
        );
      });
    });
  });

  describe('with no data', () => {
    beforeEach(() => {
      createWrapper({ props: { data: { metrics: mockUsageMetricsNoData } } });
    });

    it('should not render namespace tile', () => {
      expect(findNamespaceTile().exists()).toBe(false);
    });

    it('should render each metric a `0` for each metric', () => {
      expect(findMetrics()).toHaveLength(mockUsageMetrics.length);

      findMetrics().wrappers.forEach((v) => {
        expect(v.text()).toContain('0');
      });
    });

    it('should render each metric as a single stat with value 0', () => {
      mockUsageMetrics.forEach((_, idx) => {
        expect(findMetricValue(idx).text()).toBe('0');
      });
    });

    it('emits `showTooltip` without the last updated time', () => {
      expect(wrapper.emitted('showTooltip')).toHaveLength(1);
      expect(wrapper.emitted('showTooltip')[0][0]).toEqual(
        'Statistics on namespace usage. Usage data is a cumulative count, and updated monthly.',
      );
    });
  });

  describe('with `overviewCountsAggregationEnabled=false`', () => {
    beforeEach(() => {
      createWrapper({
        props: { data: { metrics: mockUsageMetricsNoData } },
        provide: { overviewCountsAggregationEnabled: false },
      });
    });

    it('with no data should render `-` for each metric', () => {
      expect(findMetrics()).toHaveLength(mockUsageMetrics.length);

      findMetrics().wrappers.forEach((v) => {
        expect(v.text()).toContain('-');
      });
    });

    it('emits `set-alerts` with the background aggregation warning', () => {
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);

      const alert = wrapper.emitted('set-alerts')[0][0];
      expect(alert).toEqual(
        expect.objectContaining({
          canRetry: false,
          description: 'No data available',
          title: 'Background aggregation not enabled',
          warnings: [
            {
              description:
                'To see usage overview, you must %{linkStart}enable background aggregation%{linkEnd}',
              link:
                '/help/user/analytics/value_streams_dashboard.html#enable-or-disable-overview-background-aggregation',
            },
          ],
        }),
      );
    });
  });
});
