import { GlLoadingIcon } from '@gitlab/ui';
import TracingChart from 'ee/tracing/details/tracing_chart.vue';
import TracingHeader from 'ee/tracing/details/tracing_header.vue';
import TracingDrawer from 'ee/tracing/details/tracing_drawer.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingDetails from 'ee/tracing/details/tracing_details.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import { mapTraceToSpanTrees } from 'ee/tracing/trace_utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/alert');
jest.mock('ee/tracing/trace_utils');

describe('TracingDetails', () => {
  let wrapper;
  let observabilityClientMock;

  const TRACE_ID = 'test-trace-id';
  const TRACING_INDEX_URL = 'https://www.gitlab.com/flightjs/Flight/-/tracing';
  const LOGS_INDEX_URL = 'https://www.gitlab.com/flightjs/Flight/-/logs';

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const findTraceDetails = () => wrapper.findComponentByTestId('trace-details');
  const findTraceChart = () => wrapper.findComponent(TracingChart);

  const findDrawer = () => wrapper.findComponent(TracingDrawer);
  const isDrawerOpen = () => findDrawer().props('open');
  const getDrawerSpan = () => findDrawer().props('span');

  const props = {
    traceId: TRACE_ID,
    tracingIndexUrl: TRACING_INDEX_URL,
    logsIndexUrl: LOGS_INDEX_URL,
  };

  const mountComponent = async () => {
    wrapper = shallowMountExtended(TracingDetails, {
      propsData: {
        ...props,
        observabilityClient: observabilityClientMock,
      },
    });
    await waitForPromises();
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    jest.spyOn(urlUtility, 'visitUrl');
    jest.spyOn(urlUtility, 'isSafeURL').mockReturnValue(true);

    observabilityClientMock = createMockClient();
  });

  it('tracks view_tracing_details_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_tracing_details_page', {}, undefined);
  });

  it('renders the loading indicator while checking if tracing is enabled', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(observabilityClientMock.isObservabilityEnabled).toHaveBeenCalled();
  });

  describe('when tracing is enabled', () => {
    const mockTrace = {
      traceId: 'test-trace-id',
      spans: [{ span_id: 'span-1' }, { span_id: 'span-2' }],
    };
    const mockTree = { roots: [{ span_id: 'span-1' }], incomplete: true };
    beforeEach(async () => {
      observabilityClientMock.isObservabilityEnabled.mockResolvedValueOnce(true);
      observabilityClientMock.fetchTrace.mockResolvedValueOnce(mockTrace);
      mapTraceToSpanTrees.mockReturnValue(mockTree);

      await mountComponent();
    });

    it('fetches the trace and renders the trace details', () => {
      expect(observabilityClientMock.isObservabilityEnabled).toHaveBeenCalled();
      expect(observabilityClientMock.fetchTrace).toHaveBeenCalled();
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findTraceDetails().exists()).toBe(true);
    });

    it('renders the chart component', () => {
      const chart = findTraceChart();
      expect(chart.exists()).toBe(true);
      expect(chart.props('trace')).toEqual(mockTrace);
      expect(chart.props('spanTrees')).toEqual(mockTree.roots);
    });

    it('renders the header', () => {
      const header = findTraceDetails().findComponent(TracingHeader);
      expect(header.exists()).toBe(true);
      expect(header.props('incomplete')).toBe(mockTree.incomplete);
      expect(header.props('trace')).toEqual(mockTrace);
      expect(header.props('logsLink')).toBe(`${LOGS_INDEX_URL}?traceId=test-trace-id&search=`);
    });

    describe('details drawer', () => {
      it('renders the details drawer initially closed', () => {
        expect(findDrawer().exists()).toBe(true);
        expect(isDrawerOpen()).toBe(false);
        expect(getDrawerSpan()).toBe(null);
      });

      const selectSpan = (spanId = 'span-1') =>
        findTraceChart().vm.$emit('span-selected', { spanId });

      it('opens the drawer and set the selected span, upond selection', async () => {
        await selectSpan();

        expect(isDrawerOpen()).toBe(true);
        expect(getDrawerSpan()).toEqual({ span_id: 'span-1' });
      });

      it('closes the drawer upon receiving the close event', async () => {
        await selectSpan();

        await findDrawer().vm.$emit('close');

        expect(isDrawerOpen()).toBe(false);
        expect(getDrawerSpan()).toBe(null);
      });

      it('closes the drawer if the same span is selected', async () => {
        await selectSpan();

        expect(isDrawerOpen()).toBe(true);

        await selectSpan();

        expect(isDrawerOpen()).toBe(false);
      });

      it('changes the selected span and keeps the drawer open, upon selecting a different span', async () => {
        await selectSpan('span-1');

        expect(isDrawerOpen()).toBe(true);

        await selectSpan('span-2');

        expect(isDrawerOpen()).toBe(true);
        expect(getDrawerSpan()).toEqual({ span_id: 'span-2' });
      });

      it('set the selected-span-in on the chart component', async () => {
        expect(findTraceChart().props('selectedSpanId')).toBeNull();
        await selectSpan();
        expect(findTraceChart().props('selectedSpanId')).toBe('span-1');
      });
    });
  });

  describe('when tracing is not enabled', () => {
    beforeEach(async () => {
      observabilityClientMock.isObservabilityEnabled.mockResolvedValueOnce(false);

      await mountComponent();
    });

    it('redirects to tracingIndexUrl', () => {
      expect(urlUtility.visitUrl).toHaveBeenCalledWith(props.tracingIndexUrl);
    });
  });

  describe('error handling', () => {
    it('if isObservabilityEnabled fails, it renders an alert and empty page', async () => {
      observabilityClientMock.isObservabilityEnabled.mockRejectedValueOnce('error');

      await mountComponent();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load trace details. Try reloading the page.',
      });
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findTraceDetails().exists()).toBe(false);
    });

    it('if fetchTrace fails, it renders an alert and empty page', async () => {
      observabilityClientMock.isObservabilityEnabled.mockReturnValueOnce(true);
      observabilityClientMock.fetchTrace.mockRejectedValueOnce('error');

      await mountComponent();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load trace details. Try reloading the page.',
      });
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findTraceDetails().exists()).toBe(false);
    });
  });
});
