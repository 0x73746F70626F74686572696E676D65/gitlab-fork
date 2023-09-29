import { nextTick } from 'vue';
import { __setMockMetadata } from '@cubejs-client/core';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { HTTP_STATUS_CREATED, HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import { createAlert } from '~/alert';

import { saveProductAnalyticsVisualization } from 'ee/analytics/analytics_dashboards/api/dashboards_api';

import AnalyticsVisualizationDesigner from 'ee/analytics/analytics_dashboards/components/analytics_visualization_designer.vue';
import VisualizationInspector from 'ee/analytics/analytics_dashboards/components/visualization_designer/analytics_visualization_inspector.vue';

import { NEW_DASHBOARD_SLUG } from 'ee/vue_shared/components/customizable_dashboard/constants';

import { mockMetaData, TEST_CUSTOM_DASHBOARDS_PROJECT } from '../mock_data';
import { BuilderComponent, QueryBuilder } from '../stubs';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));
jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api');

const showToast = jest.fn();
const routerPush = jest.fn();

describe('AnalyticsVisualizationDesigner', () => {
  let wrapper;

  const findTitleFormGroup = () => wrapper.findByTestId('visualization-title-form-group');
  const findTitleInput = () => wrapper.findByTestId('visualization-title-input');
  const findMeasureSelector = () => wrapper.findByTestId('panel-measure-selector');
  const findDimensionSelector = () => wrapper.findByTestId('panel-dimension-selector');
  const findSaveButton = () => wrapper.findByTestId('visualization-save-btn');
  const findQueryBuilder = () => wrapper.findByTestId('query-builder');
  const findVisualizationInspector = () => wrapper.findComponent(VisualizationInspector);

  const setVisualizationTitle = async (newTitle = '') => {
    await findTitleInput().vm.$emit('input', newTitle);
  };

  const setMeasurement = (type = '', subType = '') => {
    findMeasureSelector().vm.$emit('measureSelected', type, subType);
  };

  const setVisualizationType = (type = '') => {
    findVisualizationInspector().vm.$emit('selectVisualizationType', type);
  };

  const setAllRequiredFields = async () => {
    await setVisualizationTitle('New Title');
    setMeasurement('pageViews', 'all');
    setVisualizationType('SingleStat');
  };

  const mockSaveVisualizationImplementation = async (responseCallback) => {
    saveProductAnalyticsVisualization.mockImplementation(responseCallback);

    await waitForPromises();
  };

  const createWrapper = (sourceDashboardSlug) => {
    const mocks = {
      $toast: {
        show: showToast,
      },
      $route: {
        params: {
          dashboard: sourceDashboardSlug || '',
        },
      },
      $router: {
        push: routerPush,
      },
    };

    wrapper = shallowMountExtended(AnalyticsVisualizationDesigner, {
      stubs: {
        RouterView: true,
        BuilderComponent,
        QueryBuilder,
      },
      mocks,
      provide: {
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    it('should render title input', () => {
      expect(findTitleInput().exists()).toBe(true);
    });

    it('should not render dimension selector', () => {
      expect(findDimensionSelector().exists()).toBe(false);
    });
  });

  describe('query builder', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    it('shows an alert when a query error occurs', () => {
      const error = new Error();
      findQueryBuilder().vm.$emit('queryStatus', { error });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while loading data',
        captureError: true,
        error,
      });
    });
  });

  describe('when saving', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    describe('and there is no title', () => {
      beforeEach(() => {
        findTitleInput().element.focus = jest.fn();

        return findSaveButton().vm.$emit('click');
      });

      it('does not save the dashboard', () => {
        expect(saveProductAnalyticsVisualization).not.toHaveBeenCalled();
      });

      it('shows the invalid state on the title input', () => {
        expect(findTitleFormGroup().attributes('state')).toBe(undefined);
        expect(findTitleFormGroup().attributes('invalid-feedback')).toBe('This field is required.');

        expect(findTitleInput().attributes('state')).toBe(undefined);
      });

      it('sets focus on the dashboard title input', () => {
        expect(findTitleInput().element.focus).toHaveBeenCalled();
      });

      describe('and a user then inputs a title', () => {
        beforeEach(() => setVisualizationTitle('New Title'));

        it('shows title input as valid', () => {
          expect(findTitleFormGroup().attributes('state')).toBe('true');
          expect(findTitleInput().attributes('state')).toBe('true');
        });
      });
    });

    it('creates an alert when the measurement is not selected', async () => {
      await setVisualizationTitle('New Title');
      setVisualizationType('SingleStat');

      await findSaveButton().vm.$emit('click');
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Select a measurement',
        captureError: false,
        error: null,
      });
    });

    it('creates an alert when the visualization type is not selected', async () => {
      await setVisualizationTitle('New Title');
      setMeasurement('pageViews', 'all');

      await findSaveButton().vm.$emit('click');
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Select a visualization type',
        captureError: false,
        error: null,
      });
    });

    describe('when the visualization is valid', () => {
      it('successfully saves', async () => {
        await setAllRequiredFields();
        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

        await findSaveButton().vm.$emit('click');

        expect(saveProductAnalyticsVisualization).toHaveBeenCalledWith(
          'new_title',
          {
            data: {
              query: { foo: 'bar' },
              type: 'cube_analytics',
            },
            options: {},
            type: 'SingleStat',
            version: 1,
          },
          TEST_CUSTOM_DASHBOARDS_PROJECT,
        );

        await waitForPromises();

        expect(showToast).toHaveBeenCalledWith('Visualization was saved successfully');
      });

      it('dismisses the existing alert after successfully saving', async () => {
        await setVisualizationTitle('New Title');
        await findSaveButton().vm.$emit('click');

        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

        await setAllRequiredFields();
        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });

      it('and a error happens', async () => {
        await setAllRequiredFields();
        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_FORBIDDEN }));

        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error while saving visualization.',
          error: new Error(
            `Received an unexpected HTTP status while saving visualization: ${HTTP_STATUS_FORBIDDEN}`,
          ),
          captureError: true,
        });
      });

      it('and the server responds with "A file with this name already exists"', async () => {
        await setAllRequiredFields();
        const responseError = new Error();
        responseError.response = {
          data: { message: 'A file with this name already exists' },
        };

        mockSaveVisualizationImplementation(() => {
          throw responseError;
        });

        await findSaveButton().vm.$emit('click');
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'A visualization with that name already exists.',
          error: null,
          captureError: false,
        });
      });

      it('and an error is thrown', async () => {
        await setAllRequiredFields();
        const newError = new Error();
        mockSaveVisualizationImplementation(() => {
          throw newError;
        });
        await findSaveButton().vm.$emit('click');
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          error: newError,
          message: 'Error while saving visualization.',
          captureError: true,
        });
      });
    });
  });

  describe('beforeDestroy', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    it('should dismiss the alert', async () => {
      await setVisualizationTitle('New Title');
      await findSaveButton().vm.$emit('click');

      wrapper.destroy();

      await nextTick();

      expect(mockAlertDismiss).toHaveBeenCalled();
    });
  });

  describe('when editing for dashboard', () => {
    const setupSaveDashbboard = async (dashboard) => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper(dashboard);
      await setAllRequiredFields();

      await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

      await findSaveButton().vm.$emit('click');
      await waitForPromises();
    };

    it('after save it will redirect for new dashboards', async () => {
      await setupSaveDashbboard(NEW_DASHBOARD_SLUG);

      expect(routerPush).toHaveBeenCalledWith('/new');
    });

    it('after save it will redirect for existing dashboards', async () => {
      await setupSaveDashbboard('test-source-dashboard');

      expect(routerPush).toHaveBeenCalledWith({
        name: 'dashboard-detail',
        params: {
          slug: 'test-source-dashboard',
          editing: true,
        },
      });
    });
  });
});
