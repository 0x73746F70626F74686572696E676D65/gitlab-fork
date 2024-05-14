import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import LineChart from 'ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import dataSources from 'ee/analytics/analytics_dashboards/data_sources';
import waitForPromises from 'helpers/wait_for_promises';
import AnalyticsDashboardPanel from 'ee/analytics/analytics_dashboards/components/analytics_dashboard_panel.vue';
import PanelsBase from 'ee/vue_shared/components/customizable_dashboard/panels_base.vue';
import { mockPanel, invalidVisualization } from '../mock_data';

jest.mock('ee/analytics/analytics_dashboards/data_sources', () => ({
  cube_analytics: jest.fn().mockReturnValue({
    fetch: jest.fn().mockReturnValue([]),
  }),
}));

describe('AnalyticsDashboardPanel', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findPanelsBase = () => wrapper.findComponent(PanelsBase);
  const findPanelRetryButton = () => wrapper.findComponent(GlButton);
  const findErrorMessages = () => wrapper.findByTestId('error-messages').findAll('li');
  const findErrorLink = () => wrapper.findComponent(GlLink);
  const findErrorBody = () => wrapper.findByTestId('error-body');
  const findVisualization = () => wrapper.findComponent(LineChart);

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AnalyticsDashboardPanel, {
      provide: {
        namespaceId: '1',
        namespaceName: 'Namespace name',
        namespaceFullPath: 'namespace/full/path',
        rootNamespaceName: 'MEOW',
        rootNamespaceFullPath: 'namespace',
        isProject: true,
        ...provide,
      },
      propsData: {
        title: mockPanel.title,
        visualization: mockPanel.visualization,
        queryOverrides: mockPanel.queryOverrides,
        ...props,
      },
      stubs: { PanelsBase, GlSprintf },
    });
  };

  const expectPanelLoaded = () => {
    expect(findPanelsBase().props()).toMatchObject({
      loading: false,
      showErrorState: false,
    });
  };

  const expectPanelErrored = () => {
    expect(findPanelsBase().props()).toMatchObject({
      loading: false,
      showErrorState: true,
      errorPopoverTitle: 'Failed to fetch data',
    });
  };

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the panel base component', () => {
      expect(findPanelsBase().props()).toMatchObject({
        title: mockPanel.title,
        tooltip: '',
        loading: false,
        showErrorState: false,
        errorPopoverTitle: 'Failed to fetch data',
        actions: [
          {
            text: 'Delete',
            action: expect.any(Function),
            icon: 'remove',
          },
        ],
        editing: false,
      });
    });

    it('fetches from the data source', () => {
      expect(dataSources.cube_analytics).toHaveBeenCalled();
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createWrapper({
        props: { editing: true },
      });
    });

    it('sets editing to true on the panels base', () => {
      expect(findPanelsBase().props()).toMatchObject({
        editing: true,
      });
    });
  });

  describe('when the visualization configuration is invalid', () => {
    beforeEach(() => {
      createWrapper({
        props: { visualization: invalidVisualization },
      });
    });

    it('sets the error state on the panels base component', () => {
      expect(findPanelsBase().props()).toMatchObject({
        loading: false,
        showErrorState: true,
        errorPopoverTitle: 'Invalid visualization configuration',
      });
    });

    it('renders the bad configuration error message', () => {
      expect(wrapper.text()).toContain(
        'Something is wrong with your panel visualization configuration.',
      );
    });

    it('does not render a retry button', () => {
      expect(findPanelRetryButton().exists()).toBe(false);
    });

    it('renders the error messages', () => {
      const errors = findErrorMessages();

      expect(errors).toHaveLength(2);
      expect(errors.at(0).text()).toContain("property '/version' is not: 1");
      expect(errors.at(1).text()).toContain(
        "property '/titlePropertyTypoOhNo' is invalid: error_type=schema",
      );
    });

    it('does not call the data source', () => {
      expect(dataSources.cube_analytics).not.toHaveBeenCalled();
    });

    it('renders a link to the help docs', () => {
      expect(findErrorLink().attributes('href')).toBe(
        '/help/user/analytics/analytics_dashboards#troubleshooting',
      );
    });
  });

  describe('when fetching the data', () => {
    beforeEach(() => {
      jest.spyOn(dataSources.cube_analytics(), 'fetch').mockReturnValue(new Promise(() => {}));
      createWrapper();
      return waitForPromises();
    });

    it('sets the loading state on the panels base component', () => {
      expect(findPanelsBase().props()).toMatchObject({
        loading: true,
        showErrorState: false,
      });
    });
  });

  describe('when the data has been fetched', () => {
    describe('and there is data', () => {
      const mockData = [{ name: 'foo' }];

      beforeEach(() => {
        jest.spyOn(dataSources.cube_analytics(), 'fetch').mockReturnValue(mockData);
        createWrapper();
        return waitForPromises();
      });

      it('loaded the panel', () => {
        expectPanelLoaded();
      });

      it('renders the visualization with the fetched data', () => {
        expect(findVisualization().props()).toMatchObject({
          data: mockData,
          options: mockPanel.visualization.options,
        });
      });

      describe('and the visualization emits showTooltip', () => {
        const tooltip = 'This is a tooltip';

        beforeEach(() => {
          findVisualization().vm.$emit('showTooltip', tooltip);
        });

        it('sets the tooltip on the panels base component', () => {
          expect(findPanelsBase().props('tooltip')).toBe(tooltip);
        });
      });

      describe('and the visualization emits an error', () => {
        const error = 'test error';
        let captureExceptionSpy;

        beforeEach(() => {
          captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        });

        afterEach(() => {
          captureExceptionSpy.mockRestore();
        });

        describe.each`
          canRetry | fullPanelError
          ${false} | ${false}
          ${true}  | ${false}
          ${false} | ${true}
          ${true}  | ${true}
        `(
          'canRetry: $canRetry, fullPanelError: $fullPanelError',
          ({ canRetry, fullPanelError }) => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-errors', {
                errors: [error],
                canRetry,
                fullPanelError,
              });
            });

            it('sets the error state on the panels base component', () => {
              expect(findPanelsBase().props()).toMatchObject({
                loading: false,
                showErrorState: true,
              });
            });

            it(`${fullPanelError ? 'hides' : 'shows'} the visualization`, () => {
              expect(findVisualization().exists()).toBe(!fullPanelError);
            });

            it(`${fullPanelError ? 'shows' : 'hides'} the error body`, () => {
              expect(findErrorBody().exists()).toBe(fullPanelError);
            });

            it('logs the error to Sentry', () => {
              expect(captureExceptionSpy).toHaveBeenCalledWith(error);
            });

            it(`${canRetry ? 'renders' : 'does not render'} a retry button`, () => {
              expect(findPanelRetryButton().exists()).toBe(canRetry);
            });
          },
        );
      });
    });

    describe('and the result is empty', () => {
      beforeEach(() => {
        jest.spyOn(dataSources.cube_analytics(), 'fetch').mockReturnValue(undefined);
        createWrapper();
        return waitForPromises();
      });

      it('loaded the panel', () => {
        expectPanelLoaded();
      });

      it('renders the empty state', () => {
        const text = wrapper.text();
        expect(text).toContain('No results match your query or filter.');
      });
    });

    describe('and there is a generic data source error', () => {
      let captureExceptionSpy;
      const mockGenericError = new Error('foo');

      beforeEach(() => {
        captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        jest.spyOn(dataSources.cube_analytics(), 'fetch').mockRejectedValue(mockGenericError);

        createWrapper();

        return waitForPromises();
      });

      afterEach(() => {
        captureExceptionSpy.mockRestore();
      });

      it('sets the error state on the panels base component', () => {
        expectPanelErrored();
      });

      it('logs the error to Sentry', () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(mockGenericError);
      });

      it('renders a retry button', () => {
        expect(findPanelRetryButton().text()).toBe('Retry');
      });

      it('refetches the visualization data when the retry button is clicked', async () => {
        findPanelRetryButton().vm.$emit('click');

        await waitForPromises();

        expect(dataSources.cube_analytics().fetch).toHaveBeenCalledTimes(2);
      });

      it('renders the data source connection error message', () => {
        expect(wrapper.text()).toContain(
          'Something went wrong while connecting to your data source.',
        );
      });
    });

    describe('and there is a "Bad Request" data source error', () => {
      const mockBadRequestError = new Error('Bad Request');
      mockBadRequestError.status = 400;
      mockBadRequestError.response = {
        message: 'Some specific CubeJS error',
      };

      beforeEach(() => {
        jest.spyOn(dataSources.cube_analytics(), 'fetch').mockRejectedValue(mockBadRequestError);

        createWrapper();

        return waitForPromises();
      });

      it('sets the error state on the panels base component', () => {
        expectPanelErrored();
      });

      it('does not render the retry button', () => {
        expect(findPanelRetryButton().exists()).toBe(false);
      });
    });
  });

  describe('when multiple requests are made', () => {
    let requests;

    beforeEach(() => {
      requests = [];
      jest.spyOn(dataSources.cube_analytics(), 'fetch').mockImplementation(
        () =>
          new Promise((resolve) => {
            requests.push(resolve);
          }),
      );
      createWrapper();
    });

    it('only assigns data for the most recent request', async () => {
      const initialRequestData = [{ name: 'initial' }];
      const firstRequestData = [{ name: 'first' }];
      const secondRequestData = [{ name: 'second' }];

      requests[0](initialRequestData);
      await waitForPromises();

      // trigger 2x subsequent requests by filtering
      wrapper.setProps({ filters: { startDate: new Date() } });
      await nextTick();
      wrapper.setProps({ filters: { startDate: new Date() } });
      await nextTick();

      // resolve the requests out of order
      requests[2](secondRequestData);
      await nextTick();
      requests[1](firstRequestData);
      await nextTick();

      expect(findVisualization().props('data')).toBe(secondRequestData);
    });
  });

  describe('when fetching data with filters', () => {
    const filters = {
      dateRange: {
        startDate: new Date('2015-01-01'),
        endDate: new Date('2016-01-01'),
      },
    };

    beforeEach(() => {
      jest.spyOn(dataSources.cube_analytics(), 'fetch').mockReturnValue(new Promise(() => {}));
      createWrapper({ props: { filters } });
      return waitForPromises();
    });

    it('fetches from the data source with filters', () => {
      expect(dataSources.cube_analytics().fetch).toHaveBeenCalledWith(
        expect.objectContaining({ filters }),
      );
    });
  });

  describe('title interpolation', () => {
    it.each`
      inputTitle                              | renderedTitle
      ${'title for %{namespaceName}'}         | ${'title for Namespace name'}
      ${'title for %{namespaceFullPath}'}     | ${'title for namespace/full/path'}
      ${'title for %{rootNamespaceName}'}     | ${'title for MEOW'}
      ${'title for %{rootNamespaceFullPath}'} | ${'title for namespace'}
    `('renders $renderedTitle for $inputTitle', ({ inputTitle, renderedTitle }) => {
      createWrapper({ props: { title: inputTitle } });
      expect(findPanelsBase().props('title')).toBe(renderedTitle);
    });

    it.each`
      isProject | renderedTitle
      ${true}   | ${'title for project'}
      ${false}  | ${'title for group'}
    `(
      'renders $renderedTitle for namespaceType when isProject is $isProject',
      ({ isProject, renderedTitle }) => {
        createWrapper({ props: { title: 'title for %{namespaceType}' }, provide: { isProject } });
        expect(findPanelsBase().props('title')).toBe(renderedTitle);
      },
    );
  });
});
