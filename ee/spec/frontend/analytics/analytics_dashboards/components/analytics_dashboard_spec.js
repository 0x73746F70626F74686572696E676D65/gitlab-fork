import { GlSkeletonLoader, GlEmptyState } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  HTTP_STATUS_CREATED,
  HTTP_STATUS_FORBIDDEN,
  HTTP_STATUS_BAD_REQUEST,
} from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import getAvailableVisualizations from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_visualizations.query.graphql';
import AnalyticsDashboard from 'ee/analytics/analytics_dashboards/components/analytics_dashboard.vue';
import AnalyticsDashboardPanel from 'ee/analytics/analytics_dashboards/components/analytics_dashboard_panel.vue';
import CustomizableDashboard from 'ee/vue_shared/components/customizable_dashboard/customizable_dashboard.vue';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import ValueStreamFeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';
import {
  buildDefaultDashboardFilters,
  updateApolloCache,
} from 'ee/vue_shared/components/customizable_dashboard/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  NEW_DASHBOARD,
  EVENT_LABEL_CREATED_DASHBOARD,
  EVENT_LABEL_EDITED_DASHBOARD,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_VIEWED_DASHBOARD,
} from 'ee/analytics/analytics_dashboards/constants';
import { saveCustomDashboard } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import { dashboard } from 'ee_jest/vue_shared/components/customizable_dashboard/mock_data';
import { stubComponent } from 'helpers/stub_component';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_CUSTOM_DASHBOARDS_GROUP,
  TEST_EMPTY_DASHBOARD_SVG_PATH,
  TEST_ROUTER_BACK_HREF,
  TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_DASHBOARD_GRAPHQL_404_RESPONSE,
  TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE,
  createDashboardGraphqlSuccessResponse,
  getGraphQLDashboard,
  TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  mockInvalidDashboardErrors,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api', () => ({
  saveCustomDashboard: jest.fn(),
}));

jest.mock('ee/vue_shared/components/customizable_dashboard/utils', () => ({
  ...jest.requireActual('ee/vue_shared/components/customizable_dashboard/utils'),
  updateApolloCache: jest.fn(),
}));

const showToast = jest.fn();

Vue.use(VueApollo);

describe('AnalyticsDashboard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const namespaceId = '1';

  const findDashboard = () => wrapper.findComponent(CustomizableDashboard);
  const findAllPanels = () => wrapper.findAllComponents(AnalyticsDashboardPanel);
  const findPanelByTitle = (title) =>
    findAllPanels().wrappers.find((w) => w.props('title') === title);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findProductAnalyticsFeedbackBanner = () =>
    wrapper.findComponent(ProductAnalyticsFeedbackBanner);
  const findValueStreamFeedbackBanner = () => wrapper.findComponent(ValueStreamFeedbackBanner);
  const findInvalidDashboardAlert = () =>
    wrapper.findByTestId('analytics-dashboard-invalid-config-alert');

  const mockSaveDashboardImplementation = async (responseCallback, dashboardToSave = dashboard) => {
    saveCustomDashboard.mockImplementation(responseCallback);

    await waitForPromises();

    findDashboard().vm.$emit('save', dashboardToSave.slug, dashboardToSave);
  };

  const getFirstParsedDashboard = (dashboards) => {
    const firstDashboard = dashboards.data.project.customizableDashboards.nodes[0];

    const panels = firstDashboard.panels?.nodes || [];

    return {
      ...firstDashboard,
      panels,
    };
  };

  const mockCustomizableDashboardDeletePanel = jest.fn();

  let mockAnalyticsDashboardsHandler = jest.fn();
  let mockAvailableVisualizationsHandler = jest.fn();

  const mockDashboardResponse = (response) => {
    mockAnalyticsDashboardsHandler = jest.fn().mockResolvedValue(response);
  };
  const mockAvailableVisualizationsResponse = (response) => {
    mockAvailableVisualizationsHandler = jest.fn().mockResolvedValue(response);
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler = jest.fn();
    mockAvailableVisualizationsHandler = jest.fn();
    mockCustomizableDashboardDeletePanel.mockRestore();
  });

  const breadcrumbState = { updateName: jest.fn() };

  const mockNamespace = {
    namespaceId,
    namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
  };

  const createWrapper = ({
    props = {},
    routeSlug = '',
    provide = {},
    stubMockMethods = {},
  } = {}) => {
    const mocks = {
      $toast: {
        show: showToast,
      },
      $route: {
        params: {
          slug: routeSlug,
        },
      },
      $router: {
        replace() {},
        push() {},
        resolve: () => ({ href: TEST_ROUTER_BACK_HREF }),
      },
    };

    const mockApollo = createMockApollo([
      [getCustomizableDashboardQuery, mockAnalyticsDashboardsHandler],
      [getAvailableVisualizations, mockAvailableVisualizationsHandler],
    ]);

    wrapper = shallowMountExtended(AnalyticsDashboard, {
      apolloProvider: mockApollo,
      propsData: {
        ...props,
      },
      stubs: {
        RouterLink: true,
        RouterView: true,
        CustomizableDashboard: stubComponent(CustomizableDashboard, {
          methods: {
            ...stubMockMethods,
            deletePanel: mockCustomizableDashboardDeletePanel,
          },
          template: `<div>
            <template v-for="panel in initialDashboard.panels">
              <slot name="panel" v-bind="{ panel, filters: defaultFilters, deletePanel, editing: false }"></slot>
            </template>
          </div>`,
        }),
      },
      mocks,
      provide: {
        ...mockNamespace,
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
        dashboardEmptyStateIllustrationPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        breadcrumbState,
        isGroup: false,
        isProject: true,
        overviewCountsAggregationEnabled: true,
        ...provide,
      },
    });
  };

  const setupDashboard = (dashboardResponse, slug = '') => {
    mockDashboardResponse(dashboardResponse);
    mockAvailableVisualizationsResponse(TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE);

    createWrapper({
      routeSlug: slug || dashboardResponse.data.project.customizableDashboards.nodes[0]?.slug,
    });

    return waitForPromises();
  };

  describe('when mounted', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
    });

    it('should render with mock dashboard with filter properties', async () => {
      createWrapper();

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: '',
        isGroup: false,
        isProject: true,
      });

      expect(findDashboard().props()).toMatchObject({
        initialDashboard: getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
        defaultFilters: buildDefaultDashboardFilters(''),
        dateRangeLimit: 0,
        showDateRangeFilter: true,
        syncUrlFilters: true,
        changesSaved: false,
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');
    });

    it('should render the loading icon while fetching data', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      expect(findLoader().exists()).toBe(true);

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
    });

    it('should render dashboard by slug', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: 'audience',
        isGroup: false,
        isProject: true,
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');

      expect(findDashboard().exists()).toBe(true);
    });

    it('should not render invalid dashboard alert', async () => {
      createWrapper();

      await waitForPromises();

      expect(findInvalidDashboardAlert().exists()).toBe(false);
    });

    it('should add unique panel ids to each panel', async () => {
      createWrapper();

      await waitForPromises();

      expect(findDashboard().props().initialDashboard.panels).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: expect.stringContaining('panel-'),
          }),
        ]),
      );
    });

    it('renders an analytics dashboard panel component for each panel', async () => {
      createWrapper();

      await waitForPromises();

      const { panels } = getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(findAllPanels().length).toBe(panels.length);

      panels.forEach((panel) => {
        expect(findPanelByTitle(panel.title).props()).toMatchObject({
          title: panel.title,
          visualization: panel.visualization,
          queryOverrides: panel.queryOverrides || undefined,
          filters: buildDefaultDashboardFilters(''),
          editing: false,
        });
      });
    });

    describe('and a panel emits a "delete" event', () => {
      beforeEach(async () => {
        createWrapper();

        await waitForPromises();

        findAllPanels().at(0).vm.$emit('delete');
      });

      it('calls the delete method on CustomizableDashboard', () => {
        expect(mockCustomizableDashboardDeletePanel).toHaveBeenCalled();
      });
    });
  });

  describe('when dashboard fails to load', () => {
    let error = new Error();

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

      createWrapper();
      return waitForPromises();
    });

    it('does not render the dashboard, loader or feedback banners', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
      expect(findValueStreamFeedbackBanner().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('creates an alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining(
          'ruh roh some error. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}',
        ),
        messageLinks: {
          link: '/help/user/analytics/analytics_dashboards#troubleshooting',
        },
        captureError: true,
        error,
        title: 'Failed to load dashboard',
      });
    });

    describe('with a specified error message', () => {
      error = new Error('ruh roh some error');

      beforeEach(() => {
        mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

        createWrapper();
        return waitForPromises();
      });

      it('creates an alert with the error message and a troubleshooting link', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringContaining(
            'ruh roh some error. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}',
          ),
          messageLinks: {
            link: '/help/user/analytics/analytics_dashboards#troubleshooting',
          },
          captureError: true,
          error,
          title: 'Failed to load dashboard',
        });
      });
    });
  });

  describe('when a custom dashboard cannot be found', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_404_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the dashboard or loader', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('renders the empty state', () => {
      expect(findEmptyState().props()).toMatchObject({
        svgPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        title: 'Dashboard not found',
        description: 'No dashboard matches the specified URL path.',
        primaryButtonText: 'View available dashboards',
        primaryButtonLink: TEST_ROUTER_BACK_HREF,
      });
    });
  });

  describe("when the dashboard's configuration is invalid", () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('renders the dashboard', () => {
      expect(findDashboard().exists()).toBe(true);
    });

    it('renders an alert with error messages', () => {
      expect(findInvalidDashboardAlert().props()).toMatchObject({
        title: 'Invalid dashboard configuration',
        primaryButtonText: 'Learn more',
        primaryButtonLink: '/help/user/analytics/analytics_dashboards#troubleshooting',
        dismissible: false,
      });

      mockInvalidDashboardErrors.forEach((error) =>
        expect(findInvalidDashboardAlert().text()).toContain(error),
      );
    });
  });

  describe('available visualizations', () => {
    it('fetches the available visualizations when a custom dashboard is loaded', async () => {
      await setupDashboard(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(mockAvailableVisualizationsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        isGroup: false,
        isProject: true,
      });

      const visualizations =
        TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE.data.project
          .customizableDashboardVisualizations.nodes;

      expect(findDashboard().props().availableVisualizations).toMatchObject({
        loading: false,
        visualizations,
      });
    });

    it('fetches the available visualizations from the backend when a dashboard is new', async () => {
      await setupDashboard(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE, NEW_DASHBOARD);

      expect(mockAvailableVisualizationsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        isGroup: false,
        isProject: true,
      });
    });

    it('does not fetch the available visualizations when a builtin dashboard is loaded it', async () => {
      await setupDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(mockAvailableVisualizationsHandler).not.toHaveBeenCalled();
      expect(findDashboard().props().availableVisualizations).toMatchObject({});
    });

    it('does not fetch the available visualizations when a dashboard was not loaded', async () => {
      await setupDashboard(TEST_DASHBOARD_GRAPHQL_404_RESPONSE);

      expect(mockAvailableVisualizationsHandler).not.toHaveBeenCalled();
      expect(findDashboard().exists()).toBe(false);
    });

    describe('when available visualizations fail to load', () => {
      const error = new Error('ruh roh some error');

      beforeEach(() => {
        mockDashboardResponse(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
        mockAvailableVisualizationsHandler = jest.fn().mockRejectedValue(error);

        createWrapper({
          routeSlug:
            TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards
              .nodes[0]?.slug,
        });
        return waitForPromises();
      });

      it('renders the dashboard', () => {
        expect(findDashboard().exists()).toBe(true);
      });

      it('sets error state on the visualizations drawer', () => {
        expect(findDashboard().props().availableVisualizations).toMatchObject({
          loading: false,
          hasError: true,
          visualizations: [],
        });
      });

      it(`should capture the exception in Sentry`, () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });
  });

  describe('dashboard editor', () => {
    beforeEach(() =>
      mockAvailableVisualizationsResponse(TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE),
    );

    describe('when saving', () => {
      beforeEach(() => {
        mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

        createWrapper({
          routeSlug: 'custom_dashboard',
        });
      });

      describe('with a valid dashboard', () => {
        let originalPanels;

        beforeEach(async () => {
          await waitForPromises();

          originalPanels = findDashboard().props().initialDashboard.panels;

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        });

        it('saves the dashboard and shows a success toast', () => {
          expect(saveCustomDashboard).toHaveBeenCalledWith({
            dashboardSlug: 'analytics_overview',
            dashboardConfig: expect.objectContaining({
              title: 'Analytics Overview',
              panels: expect.any(Array),
            }),
            projectInfo: TEST_CUSTOM_DASHBOARDS_PROJECT,
            isNewFile: false,
          });

          expect(showToast).toHaveBeenCalledWith('Dashboard was saved successfully');
        });

        it('sets changesSaved to true on the dashboard component', () => {
          expect(findDashboard().props('changesSaved')).toBe(true);
        });

        it(`tracks the "${EVENT_LABEL_EDITED_DASHBOARD}" event`, () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_EDITED_DASHBOARD,
            {
              label: 'Analytics Overview',
            },
            undefined,
          );
        });

        it('persists the original panels array after saving', () => {
          expect(findDashboard().props().initialDashboard.panels).toStrictEqual(originalPanels);
        });
      });

      describe('with an invalid dashboard', () => {
        it('does not save when dashboard has no title', async () => {
          const { title, ...dashboardWithNoTitle } = dashboard;
          await mockSaveDashboardImplementation(
            () => ({ status: HTTP_STATUS_CREATED }),
            dashboardWithNoTitle,
          );

          expect(saveCustomDashboard).not.toHaveBeenCalled();
        });
      });

      describe('dashboard errors', () => {
        it('creates an alert when the response status is HTTP_STATUS_FORBIDDEN', async () => {
          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_FORBIDDEN }));

          expect(createAlert).toHaveBeenCalledWith({
            message: 'Error while saving dashboard',
            captureError: true,
            error: new Error(`Bad save dashboard response. Status:${HTTP_STATUS_FORBIDDEN}`),
            title: '',
          });
        });

        it('creates an alert when the fetch request throws an error', async () => {
          const newError = new Error();
          await mockSaveDashboardImplementation(() => {
            throw newError;
          });

          expect(createAlert).toHaveBeenCalledWith({
            error: newError,
            message: 'Error while saving dashboard',
            captureError: true,
            title: '',
          });
        });

        it('clears the alert when the component is destroyed', async () => {
          await mockSaveDashboardImplementation(() => {
            throw new Error();
          });

          wrapper.destroy();

          await nextTick();

          expect(mockAlertDismiss).toHaveBeenCalled();
        });

        it('clears the alert when the dashboard saved successfully', async () => {
          await mockSaveDashboardImplementation(() => {
            throw new Error();
          });

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));

          expect(mockAlertDismiss).toHaveBeenCalled();
        });
      });

      it('renders an alert with the server message when a bad request was made', async () => {
        createWrapper({
          routeSlug: 'custom_dashboard',
        });

        const message = 'File already exists';
        const badRequestError = new Error();

        badRequestError.response = {
          status: HTTP_STATUS_BAD_REQUEST,
          data: { message },
        };

        await mockSaveDashboardImplementation(() => {
          throw badRequestError;
        });

        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message,
          error: badRequestError,
          captureError: false,
          title: '',
        });
      });

      it('updates the apollo cache', async () => {
        createWrapper({
          routeSlug: dashboard.slug,
        });

        await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        await waitForPromises();

        expect(updateApolloCache).toHaveBeenCalledWith({
          apolloClient: expect.any(Object),
          slug: dashboard.slug,
          dashboard: expect.objectContaining({
            slug: 'analytics_overview',
            title: 'Analytics Overview',
            userDefined: true,
          }),
          fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
          isGroup: false,
          isProject: true,
        });
      });
    });

    describe('when a dashboard is new', () => {
      beforeEach(() => {
        createWrapper({
          props: { isNewDashboard: true },
        });

        return waitForPromises();
      });

      it('creates a new dashboard and and disables the filter syncing', () => {
        expect(findDashboard().props()).toMatchObject({
          initialDashboard: {
            ...NEW_DASHBOARD,
          },
          defaultFilters: buildDefaultDashboardFilters(''),
          showDateRangeFilter: true,
          syncUrlFilters: false,
        });
      });

      it(`tracks the "${EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD}" event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
          {},
          undefined,
        );
      });

      it(`tracks the "${EVENT_LABEL_VIEWED_DASHBOARD}" event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(EVENT_LABEL_VIEWED_DASHBOARD, {}, undefined);
      });

      describe('when saving', () => {
        let originalPanels;

        beforeEach(async () => {
          await waitForPromises();

          originalPanels = findDashboard().props().initialDashboard.panels;

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        });

        it('saves the dashboard as a new file', () => {
          expect(saveCustomDashboard).toHaveBeenCalledWith({
            dashboardSlug: 'analytics_overview',
            dashboardConfig: expect.objectContaining({
              title: 'Analytics Overview',
              panels: expect.any(Array),
            }),
            projectInfo: TEST_CUSTOM_DASHBOARDS_PROJECT,
            isNewFile: true,
          });
        });

        it(`tracks the "${EVENT_LABEL_CREATED_DASHBOARD}" event`, () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_CREATED_DASHBOARD,
            {
              label: 'Analytics Overview',
            },
            undefined,
          );
        });

        it('persists the original panels array after saving', () => {
          expect(findDashboard().props().initialDashboard.panels).toStrictEqual(originalPanels);
        });
      });
    });
  });

  describe.each`
    userDefined | event                                   | title
    ${false}    | ${EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD} | ${'Audience'}
    ${true}     | ${EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD}  | ${'My custom dashboard'}
  `('when a dashboard is userDefined=$userDefined is viewed', ({ userDefined, event, title }) => {
    beforeEach(() => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(getGraphQLDashboard({ userDefined, title })),
      );

      return waitForPromises();
    });

    it(`tracks the "${event}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(event, { label: title }, undefined);
    });

    it(`tracks the "${EVENT_LABEL_VIEWED_DASHBOARD}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_LABEL_VIEWED_DASHBOARD,
        { label: title },
        undefined,
      );
    });

    it('tracks exactly two events', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('with a built-in product analytics dashboards dashboard', () => {
    it.each`
      slug          | userDefined | showsBanner
      ${'audience'} | ${false}    | ${true}
      ${'behavior'} | ${false}    | ${true}
      ${'vsd'}      | ${false}    | ${false}
      ${'audience'} | ${true}     | ${false}
    `(
      'when the dashboard slug is "$slug" and userDefined is $userDefined then the banner is $showsBanner',
      async ({ slug, userDefined, showsBanner }) => {
        setupDashboard(
          createDashboardGraphqlSuccessResponse(getGraphQLDashboard({ slug, userDefined })),
        );

        await waitForPromises();

        expect(findProductAnalyticsFeedbackBanner().exists()).toBe(showsBanner);
      },
    );
  });

  describe('with an AI impact dashboard', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      return waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'AI impact analytics',
          slug: 'ai_impact',
        },
        showDateRangeFilter: false,
        showAnonUsersFilter: false,
      });
    });

    it('does not render the value stream feedback banner', () => {
      expect(findValueStreamFeedbackBanner().exists()).toBe(false);
    });

    it('does not render the product analytics feedback banner', () => {
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
    });
  });

  describe('with a value stream dashboard', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      await waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
        },
        showDateRangeFilter: false,
        showAnonUsersFilter: false,
      });
    });

    it('renders the value stream feedback banner', () => {
      expect(findValueStreamFeedbackBanner().exists()).toBe(true);
    });

    it('does not render the product analytics feedback banner', () => {
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
    });
  });

  describe('with a group namespace', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceId: TEST_CUSTOM_DASHBOARDS_GROUP.id,
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });
      await waitForPromises();
    });

    it('will fetch the group data', () => {
      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
        slug: 'value_streams_dashboard',
        isGroup: true,
        isProject: false,
      });
    });

    it('will set the initialDashboard data', async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceId: TEST_CUSTOM_DASHBOARDS_GROUP.id,
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });

      await waitForPromises();

      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
          panels: [],
        },
        showDateRangeFilter: false,
      });
    });
  });

  describe('when the route changes', () => {
    const nextMock = jest.fn();

    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
    });

    const setupWithConfirmation = async (confirmMock) => {
      createWrapper({ stubMockMethods: { confirmDiscardIfChanged: confirmMock } });

      await waitForPromises();

      wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

      await waitForPromises();
    };

    it('routes to the next route when a user confirmed to discard changes', async () => {
      const confirmMock = jest.fn().mockResolvedValue(true);

      await setupWithConfirmation(confirmMock);

      expect(confirmMock).toHaveBeenCalledTimes(1);
      expect(nextMock).toHaveBeenCalled();
    });

    it('does not route to the next route when a user does not confirm to discard changes', async () => {
      const confirmMock = jest.fn().mockResolvedValue(false);

      await setupWithConfirmation(confirmMock);

      expect(confirmMock).toHaveBeenCalledTimes(1);
      expect(nextMock).not.toHaveBeenCalled();
    });
  });
});
