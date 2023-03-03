import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AnalyticsDashboard from 'ee/product_analytics/dashboards/components/analytics_dashboard.vue';
import CustomizableDashboard from 'ee/vue_shared/components/customizable_dashboard/customizable_dashboard.vue';
import { dashboard } from 'ee_jest/vue_shared/components/customizable_dashboard/mock_data';
import { buildDefaultDashboardFilters } from 'ee/vue_shared/components/customizable_dashboard/utils';

import {
  getCustomDashboard,
  getProductAnalyticsVisualizationList,
  getProductAnalyticsVisualization,
} from 'ee/analytics/analytics_dashboards/api/dashboards_api';

import {
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_CUSTOM_DASHBOARD,
} from '../../../analytics/analytics_dashboards/mock_data';

jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api');

describe('AnalyticsDashboard', () => {
  let wrapper;

  const findDashboard = () => wrapper.findComponent(CustomizableDashboard);
  const findLoader = () => wrapper.findComponent(GlLoadingIcon);

  beforeEach(() => {
    getCustomDashboard.mockImplementation(() => TEST_CUSTOM_DASHBOARD);
    getProductAnalyticsVisualizationList.mockImplementation(() => []);
    getProductAnalyticsVisualization.mockImplementation(() => TEST_CUSTOM_DASHBOARD);
  });

  const createWrapper = (data = {}, routeId) => {
    const mocks = {
      $route: {
        params: {
          id: routeId || '',
        },
      },
      $router: {
        replace() {},
        push() {},
      },
    };

    wrapper = shallowMountExtended(AnalyticsDashboard, {
      data() {
        return {
          dashboard: null,
          ...data,
        };
      },
      stubs: ['router-link', 'router-view'],
      mocks,
      provide: {
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
      },
    });
  };

  describe('when mounted', () => {
    it('should render with mock dashboard with filter properties', async () => {
      createWrapper({
        dashboard,
      });

      expect(getCustomDashboard).toHaveBeenCalledWith('', TEST_CUSTOM_DASHBOARDS_PROJECT);

      expect(findDashboard().props()).toMatchObject({
        initialDashboard: dashboard,
        defaultFilters: buildDefaultDashboardFilters(''),
        showDateRangeFilter: true,
        syncUrlFilters: true,
      });
    });

    it('should render the loading icon while fetching data', async () => {
      createWrapper({}, 'dashboard_audience');

      expect(findLoader().exists()).toBe(true);

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
    });

    it('should render audience dashboard by id', async () => {
      createWrapper({}, 'dashboard_audience');

      await waitForPromises();

      expect(getCustomDashboard).toHaveBeenCalledTimes(0);
      expect(getProductAnalyticsVisualizationList).toHaveBeenCalledWith(
        TEST_CUSTOM_DASHBOARDS_PROJECT,
      );
      expect(getProductAnalyticsVisualization).toHaveBeenCalledTimes(0);

      expect(findDashboard().exists()).toBe(true);
    });

    it('should render behavior dashboard by id', async () => {
      createWrapper({}, 'dashboard_behavior');

      await waitForPromises();

      expect(getCustomDashboard).toHaveBeenCalledTimes(0);
      expect(getProductAnalyticsVisualizationList).toHaveBeenCalledWith(
        TEST_CUSTOM_DASHBOARDS_PROJECT,
      );
      expect(getProductAnalyticsVisualization).toHaveBeenCalledTimes(0);

      expect(findDashboard().exists()).toBe(true);
    });

    it('should render custom dashboard by id', async () => {
      createWrapper({}, 'custom_dashboard');

      await waitForPromises();

      expect(getCustomDashboard).toHaveBeenCalledWith(
        'custom_dashboard',
        TEST_CUSTOM_DASHBOARDS_PROJECT,
      );
      expect(getProductAnalyticsVisualizationList).toHaveBeenCalledWith(
        TEST_CUSTOM_DASHBOARDS_PROJECT,
      );
      expect(getProductAnalyticsVisualization).toHaveBeenCalledWith(
        'page_views_per_day',
        TEST_CUSTOM_DASHBOARDS_PROJECT,
      );

      expect(findDashboard().exists()).toBe(true);
    });
  });
});
