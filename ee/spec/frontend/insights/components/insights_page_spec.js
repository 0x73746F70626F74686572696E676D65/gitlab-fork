import { GlEmptyState } from '@gitlab/ui';
import { GlColumnChart } from '@gitlab/ui/dist/charts';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import InsightsChart from 'ee/insights/components/insights_chart.vue';
import InsightsPage from 'ee/insights/components/insights_page.vue';
import { createStore } from 'ee/insights/stores';
import {
  chartInfo,
  pageInfo,
  pageInfoNoCharts,
  barChartData,
  mockFilterLabels,
  mockCollectionLabels,
  mockGroupBy,
} from 'ee_jest/insights/mock_data';
import { TEST_HOST } from 'helpers/test_constants';
import { CHART_TYPES } from 'ee/insights/constants';

Vue.use(Vuex);

describe('Insights page component', () => {
  let store;
  let wrapper;
  let trackingSpy;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(InsightsPage, {
      store,
      propsData: {
        queryEndpoint: `${TEST_HOST}/query`,
        pageConfig: pageInfoNoCharts,
        ...props,
      },
    });
  };

  const createLoadingChartData = () => {
    return pageInfo.charts.reduce((memo, chart) => {
      return { ...memo, [chart.title]: {} };
    }, {});
  };

  const createLoadedChartData = () => {
    return pageInfo.charts.reduce((memo, chart) => {
      return {
        ...memo,
        [chart.title]: {
          loaded: true,
          type: chart.type,
          description: '',
          data: barChartData,
          dataSourceType: 'issue',
          filterLabels: mockFilterLabels,
          collectionLabels: mockCollectionLabels,
          groupBy: mockGroupBy,
          error: null,
        },
      };
    }, {});
  };

  const expectTrackingAction = (action) =>
    expect(trackingSpy).toHaveBeenCalledWith(undefined, action, expect.any(Object));

  const findInsightsChartData = () => wrapper.findComponent(InsightsChart);

  beforeEach(() => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation(() => {});
  });

  describe('no chart config available', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not fetch chart data when mounted', () => {
      expect(store.dispatch).not.toHaveBeenCalled();
    });

    it('shows an empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    });
  });

  describe('charts configured', () => {
    beforeEach(() => {
      createComponent({ pageConfig: pageInfo });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    afterEach(() => {
      unmockTracking();
    });

    it('fetches chart data when mounted', () => {
      expect(store.dispatch).toHaveBeenCalledWith('insights/fetchChartData', {
        endpoint: `${TEST_HOST}/query`,
        chart: chartInfo,
      });
    });

    it('does not show empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(false);
    });

    describe('pageConfig changes', () => {
      it('reflects new state', async () => {
        wrapper.setProps({ pageConfig: pageInfoNoCharts });

        await nextTick();

        expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
      });
    });

    describe('when charts loading', () => {
      beforeEach(() => {
        store.state.insights.chartData = createLoadingChartData();
      });

      it('renders loading state', () => {
        expect(findInsightsChartData().props()).toMatchObject({
          loaded: false,
        });
      });

      it('does not display chart', () => {
        expect(wrapper.findComponent(GlColumnChart).exists()).toBe(false);
      });
    });

    describe('charts configured and loaded', () => {
      beforeEach(() => {
        store.state.insights.chartData = createLoadedChartData();
      });

      it('passes correct props to chart component', () => {
        expect(findInsightsChartData().props()).toMatchObject({
          loaded: true,
          type: CHART_TYPES.BAR,
          description: '',
          data: barChartData,
          dataSourceType: 'issue',
          filterLabels: mockFilterLabels,
          collectionLabels: mockCollectionLabels,
          groupBy: mockGroupBy,
          error: null,
        });
      });

      describe('chart item clicked', () => {
        const trackingChartItemClickedAction = 'insights_chart_item_clicked';
        const trackingChartTypeItemClickedAction = 'insights_issue_chart_item_clicked';

        beforeEach(() => {
          findInsightsChartData().vm.$emit('chart-item-clicked');
        });

        it('should send two tracking events', () => {
          expect(trackingSpy).toHaveBeenCalledTimes(2);
        });

        it(`should track the '${trackingChartItemClickedAction}' event`, () => {
          expectTrackingAction(trackingChartItemClickedAction);
        });

        it(`should track the '${trackingChartTypeItemClickedAction}' event`, () => {
          expectTrackingAction(trackingChartTypeItemClickedAction);
        });
      });
    });
  });
});
