import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import TracingAnalytics from 'ee/tracing/list/tracing_analytics.vue';
import FilteredSearch from 'ee/tracing/list/filter_bar/tracing_filtered_search.vue';
import TracingTableList from 'ee/tracing/list/tracing_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingList from 'ee/tracing/list/tracing_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockClient } from 'helpers/mock_observability_client';
import * as commonUtils from '~/lib/utils/common_utils';
import axios from '~/lib/utils/axios_utils';

jest.mock('~/lib/utils/axios_utils');

jest.mock('~/alert');

describe('TracingList', () => {
  let wrapper;
  let observabilityClientMock;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTableList = () => wrapper.findComponent(TracingTableList);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findInfiniteScrolling = () => wrapper.findComponent(GlInfiniteScroll);
  const findAnalytics = () => wrapper.findComponent(TracingAnalytics);
  const bottomReached = async () => {
    findInfiniteScrolling().vm.$emit('bottomReached');
    await waitForPromises();
  };
  const setFilters = async (filters) => {
    findFilteredSearch().vm.$emit('filter', filters);
    await waitForPromises();
  };

  const mockResponse = {
    traces: [{ trace_id: 'trace1' }, { trace_id: 'trace2' }],
    next_page_token: 'page-2',
  };

  const mockAnalytics = [
    {
      interval: 1706456580,
      count: 272,
      p90_duration_nano: 79431434,
      p95_duration_nano: 172512624,
      p75_duration_nano: 33666014,
      p50_duration_nano: 13540992,
      trace_rate: 4.533333333333333,
    },
    {
      interval: 1706456640,
      count: 322,
      p90_duration_nano: 245701137,
      p95_duration_nano: 410402110,
      p75_duration_nano: 126097516,
      p50_duration_nano: 26955796,
      trace_rate: 5.366666666666666,
    },
  ];

  const mountComponent = async () => {
    wrapper = shallowMountExtended(TracingList, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
      },
    });
    await waitForPromises();
  };

  beforeEach(() => {
    observabilityClientMock = createMockClient();

    observabilityClientMock.fetchTraces.mockResolvedValue(mockResponse);
    observabilityClientMock.fetchTracesAnalytics.mockResolvedValue(mockAnalytics);
  });

  describe('trace list', () => {
    describe('while fetching traces', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTraces.mockReturnValue(new Promise(() => {}));

        await mountComponent();
      });

      it('fetches traces', () => {
        expect(observabilityClientMock.fetchTraces).toHaveBeenCalled();
      });

      it('renders the loading icon while fetching traces', () => {
        expect(findLoadingIcon().exists()).toBe(true);
        expect(findTableList().exists()).toBe(false);
        expect(findFilteredSearch().exists()).toBe(true);
        expect(findInfiniteScrolling().exists()).toBe(false);
      });
    });

    describe('when fetching traces completes', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTraces.mockResolvedValue(mockResponse);

        await mountComponent();
      });
      it('renders the trace list with filtered search', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findTableList().exists()).toBe(true);
        expect(findFilteredSearch().exists()).toBe(true);
        expect(findUrlSync().exists()).toBe(true);
        expect(findTableList().props('traces')).toEqual(mockResponse.traces);
        expect(findInfiniteScrolling().exists()).toBe(true);
      });
    });
  });

  describe('analytics', () => {
    describe('while fetching analytics', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(new Promise(() => {}));
        await mountComponent();
      });

      it('fetches analytics', () => {
        expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenCalled();
      });

      it('sets loading prop while fetching analytics', () => {
        expect(findAnalytics().exists()).toBe(true);
        expect(findAnalytics().props('loading')).toBe(true);
      });
    });

    describe('when fetching analytics is done', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockResolvedValue(mockAnalytics);

        await mountComponent();
      });
      it('renders the analytics component', () => {
        expect(findAnalytics().exists()).toBe(true);
        expect(findAnalytics().props('analytics')).toEqual(mockAnalytics);
        expect(findAnalytics().props('loading')).toBe(false);
      });
    });

    describe('chart height', () => {
      const mountWithSize = (contentTop, innerHeight) => {
        jest.spyOn(commonUtils, 'contentTop').mockReturnValue(contentTop);
        window.innerHeight = innerHeight;
      };
      it('sets the chart height to 20% of the container height', async () => {
        mountWithSize(200, 1000);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(160);
      });

      it('sets the min height to 100px', async () => {
        mountWithSize(20, 200);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(100);
      });

      it('resize the chart on window resize', async () => {
        mountWithSize(200, 1000);

        await mountComponent();

        expect(findAnalytics().props('chartHeight')).toBe(160);

        jest.spyOn(commonUtils, 'contentTop').mockReturnValue(200);
        window.innerHeight = 800;
        window.dispatchEvent(new Event('resize'));

        await nextTick();

        expect(findAnalytics().props('chartHeight')).toBe(120);
      });
    });
  });

  describe('on trace-clicked', () => {
    let visitUrlMock;
    beforeEach(async () => {
      setWindowLocation('base_path');
      visitUrlMock = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});

      await mountComponent();
    });

    it('redirects to the details url', () => {
      findTableList().vm.$emit('trace-clicked', { traceId: 'test-trace-id' });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith('/base_path/test-trace-id', false);
    });

    it('opens a new tab if clicked with meta key', () => {
      findTableList().vm.$emit('trace-clicked', {
        traceId: 'test-trace-id',
        clickEvent: { metaKey: true },
      });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith('/base_path/test-trace-id', true);
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      setWindowLocation(
        '?sortBy=duration_desc' +
          '&period[]=4h' +
          '&status[]=ok' +
          '&service[]=loadgenerator' +
          '&service[]=test-service' +
          '&operation[]=test-op' +
          '&trace_id[]=test_trace&' +
          'gt%5BdurationMs%5D[]=100' +
          '&attribute[]=foo%3Dbar',
      );
      await mountComponent();
    });

    it('sets the client prop', () => {
      expect(findFilteredSearch().props('observabilityClient')).toBe(observabilityClientMock);
    });

    it('renders FilteredSeach with initial filters and sort order parsed from window.location', () => {
      expect(findFilteredSearch().props('attributesFilters')).toEqual({
        period: [{ operator: '=', value: '4h' }],
        service: [
          { operator: '=', value: 'loadgenerator' },
          { operator: '=', value: 'test-service' },
        ],
        operation: [{ operator: '=', value: 'test-op' }],
        traceId: [{ operator: '=', value: 'test_trace' }],
        durationMs: [{ operator: '>', value: '100' }],
        attribute: [{ operator: '=', value: 'foo=bar' }],
        status: [{ operator: '=', value: 'ok' }],
      });
      expect(findFilteredSearch().props('initialSort')).toBe('duration_desc');
    });

    it('sets FilteredSearch initialSort the default sort order if not specified in the query', async () => {
      setWindowLocation('?period[]=4h');
      await mountComponent();

      expect(findFilteredSearch().props('initialSort')).toBe('timestamp_desc');
    });

    it('defaults to 1h period filter if not specified in the query params', async () => {
      setWindowLocation('?sortBy=duration_desc');
      await mountComponent();

      expect(findFilteredSearch().props('attributesFilters')).toEqual({
        period: [{ operator: '=', value: '1h' }],
      });
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        attribute: ['foo=bar'],
        durationMs: null,
        'filtered-search-term': null,
        'gt[durationMs]': ['100'],
        'lt[durationMs]': null,
        'not[attribute]': null,
        'not[durationMs]': null,
        'not[filtered-search-term]': null,
        'not[operation]': null,
        'not[period]': null,
        'not[service]': null,
        'not[trace_id]': null,
        'not[status]': null,
        operation: ['test-op'],
        period: ['4h'],
        status: ['ok'],
        service: ['loadgenerator', 'test-service'],
        sortBy: 'duration_desc',
        trace_id: ['test_trace'],
      });
    });

    it('fetches traces and analytics with options', () => {
      const expectedFilters = {
        period: [{ operator: '=', value: '4h' }],
        service: [
          { operator: '=', value: 'loadgenerator' },
          { operator: '=', value: 'test-service' },
        ],
        operation: [{ operator: '=', value: 'test-op' }],
        traceId: [{ operator: '=', value: 'test_trace' }],
        durationMs: [{ operator: '>', value: '100' }],
        attribute: [{ operator: '=', value: 'foo=bar' }],
        status: [{ operator: '=', value: 'ok' }],
        search: undefined,
      };
      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          ...expectedFilters,
        },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenLastCalledWith({
        filters: {
          ...expectedFilters,
        },
        abortController: expect.any(AbortController),
      });
    });

    describe('on search submit', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchTracesAnalytics.mockReset();
        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(mockAnalytics);
        await setFilters({
          period: [{ operator: '=', value: '12h' }],
          service: [{ operator: '=', value: 'frontend' }],
          operation: [{ operator: '=', value: 'op' }],
          traceId: [{ operator: '=', value: 'another_trace' }],
          durationMs: [{ operator: '>', value: '200' }],
          attribute: [{ operator: '=', value: 'foo=baz' }],
          status: [{ operator: '=', value: 'error' }],
        });
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toEqual({
          attribute: ['foo=baz'],
          durationMs: null,
          'filtered-search-term': null,
          'gt[durationMs]': ['200'],
          'lt[durationMs]': null,
          'not[attribute]': null,
          'not[durationMs]': null,
          'not[filtered-search-term]': null,
          'not[operation]': null,
          'not[period]': null,
          'not[service]': null,
          'not[trace_id]': null,
          'not[status]': null,
          operation: ['op'],
          period: ['12h'],
          service: ['frontend'],
          sortBy: 'duration_desc',
          trace_id: ['another_trace'],
          status: ['error'],
        });
      });

      it('fetches traces and analytics with updated filters', () => {
        const expectedFilters = {
          period: [{ operator: '=', value: '12h' }],
          service: [{ operator: '=', value: 'frontend' }],
          operation: [{ operator: '=', value: 'op' }],
          traceId: [{ operator: '=', value: 'another_trace' }],
          durationMs: [{ operator: '>', value: '200' }],
          attribute: [{ operator: '=', value: 'foo=baz' }],
          status: [{ operator: '=', value: 'error' }],
        };
        expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
          filters: {
            ...expectedFilters,
          },
          pageSize: 50,
          pageToken: null,
          sortBy: 'duration_desc',
          abortController: expect.any(AbortController),
        });

        expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenLastCalledWith({
          filters: {
            ...expectedFilters,
          },
          abortController: expect.any(AbortController),
        });
      });

      it('updates FilteredSearch attributesFilters', () => {
        expect(findFilteredSearch().props('attributesFilters')).toEqual({
          period: [{ operator: '=', value: '12h' }],
          service: [{ operator: '=', value: 'frontend' }],
          operation: [{ operator: '=', value: 'op' }],
          traceId: [{ operator: '=', value: 'another_trace' }],
          durationMs: [{ operator: '>', value: '200' }],
          attribute: [{ operator: '=', value: 'foo=baz' }],
          status: [{ operator: '=', value: 'error' }],
        });
      });
    });

    describe('cancelling pending requests', () => {
      let abortSpy;
      beforeEach(async () => {
        axios.isCancel = jest.fn().mockReturnValue(true);
        abortSpy = jest.spyOn(AbortController.prototype, 'abort');

        observabilityClientMock.fetchTracesAnalytics.mockReturnValue(new Promise(() => {}));
        observabilityClientMock.fetchTraces.mockReturnValue(new Promise(() => {}));

        await mountComponent();
      });

      it('cancels pending requests', async () => {
        expect(abortSpy).not.toHaveBeenCalled();

        await setFilters({});

        // cancel fetchTraces and fetchAnalytics
        expect(abortSpy).toHaveBeenCalledTimes(2);
      });

      it('does not show any alert', async () => {
        observabilityClientMock.fetchTraces.mockRejectedValue('cancelled');
        observabilityClientMock.fetchTracesAnalytics.mockRejectedValue('cancelled');

        await setFilters({});

        expect(createAlert).not.toHaveBeenCalled();
      });

      it('does not hide the loading indicators', async () => {
        await setFilters({});

        expect(findLoadingIcon().exists()).toBe(true);
        expect(findAnalytics().props('loading')).toBe(true);
      });
    });

    describe('on sort order changed', () => {
      beforeEach(async () => {
        setWindowLocation('?sortBy=duration_desc');
        await mountComponent();

        observabilityClientMock.fetchTracesAnalytics.mockReset();

        findFilteredSearch().vm.$emit('sort', 'timestamp_asc');
        await waitForPromises();
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toMatchObject({
          sortBy: 'timestamp_asc',
        });
      });

      it('fetches traces with new sort order', () => {
        expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
          filters: {
            attribute: undefined,
            durationMs: undefined,
            operation: undefined,
            period: [{ operator: '=', value: '1h' }],
            search: undefined,
            service: undefined,
            traceId: undefined,
          },
          pageSize: 50,
          pageToken: null,
          sortBy: 'timestamp_asc',
          abortController: expect.any(AbortController),
        });
      });

      it('does not fetch analytics', () => {
        expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();
      });

      it('updates FilteredSearch initial sort', () => {
        expect(findFilteredSearch().props('initialSort')).toEqual('timestamp_asc');
      });
    });
  });

  describe('infinite scrolling', () => {
    const findLegend = () =>
      findInfiniteScrolling().find('[data-testid="tracing-infinite-scrolling-legend"]');

    beforeEach(async () => {
      setWindowLocation('?period[]=12h&service[]=loadgenerator&sortBy=duration_desc');
      await mountComponent();
    });

    it('renders the list with infinite scrolling', () => {
      const infiniteScrolling = findInfiniteScrolling();
      expect(infiniteScrolling.exists()).toBe(true);
      expect(infiniteScrolling.props('fetchedItems')).toBe(mockResponse.traces.length);
      expect(infiniteScrolling.getComponent(TracingTableList).exists()).toBe(true);
    });

    it('fetches the next page of traces when bottom reached', async () => {
      const nextPageResponse = {
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      };
      observabilityClientMock.fetchTraces.mockReturnValueOnce(nextPageResponse);

      await bottomReached();

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          attribute: undefined,
          durationMs: undefined,
          operation: undefined,
          period: [{ operator: '=', value: '12h' }],
          search: undefined,
          service: [{ operator: '=', value: 'loadgenerator' }],
          traceId: undefined,
        },
        pageSize: 50,
        pageToken: 'page-2',
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });

      expect(findInfiniteScrolling().props('fetchedItems')).toBe(
        mockResponse.traces.length + nextPageResponse.traces.length,
      );
      expect(findTableList().props('traces')).toEqual([
        ...mockResponse.traces,
        ...nextPageResponse.traces,
      ]);
    });

    it('does not fetch analytics when bottom reached', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockReset();

      await bottomReached();

      expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();
      expect(findAnalytics().exists()).toBe(true);
    });

    it('does not update the next_page_token if missing - i.e. it reached the last page', async () => {
      observabilityClientMock.fetchTraces.mockReturnValueOnce({
        traces: [],
      });

      await bottomReached();

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          attribute: undefined,
          durationMs: undefined,
          operation: undefined,
          period: [{ operator: '=', value: '12h' }],
          search: undefined,
          service: [{ operator: '=', value: 'loadgenerator' }],
          traceId: undefined,
        },
        pageSize: 50,
        pageToken: 'page-2',
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });
    });

    it('does not show legend when there are 0 items', async () => {
      observabilityClientMock.fetchTraces.mockReturnValue({
        traces: [],
      });
      await mountComponent();
      expect(findLegend().text()).toBe('');
    });

    it('shows the number of fetched items as the legend', () => {
      expect(findLegend().text()).toBe(`Showing ${mockResponse.traces.length} traces`);
    });

    it('shows the spinner when fetching the next page', async () => {
      bottomReached();
      await nextTick();

      expect(findInfiniteScrolling().findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findLegend().exists()).toBe(false);
    });

    it('when filters change, pagination and traces are reset', async () => {
      observabilityClientMock.fetchTraces.mockReturnValueOnce({
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      });
      await bottomReached();

      await setFilters({ period: [{ operator: '=', value: '4h' }] });

      const expectedFilters = {
        attribute: undefined,
        durationMs: undefined,
        operation: undefined,
        period: [{ operator: '=', value: '4h' }],
        search: undefined,
        service: undefined,
        traceId: undefined,
      };

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: { ...expectedFilters },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_desc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).toHaveBeenCalledWith({
        filters: { ...expectedFilters },
        abortController: expect.any(AbortController),
      });

      expect(findTableList().props('traces')).toEqual(mockResponse.traces);
    });

    it('when sort order is changed, pagination and traces are reset', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockReset();
      observabilityClientMock.fetchTraces.mockReturnValueOnce({
        traces: [{ trace_id: 'trace-3' }],
        next_page_token: 'page-3',
      });
      await bottomReached();

      findFilteredSearch().vm.$emit('sort', 'duration_asc');
      await waitForPromises();

      expect(observabilityClientMock.fetchTraces).toHaveBeenLastCalledWith({
        filters: {
          attribute: undefined,
          durationMs: undefined,
          operation: undefined,
          period: [{ operator: '=', value: '12h' }],
          search: undefined,
          service: [{ operator: '=', value: 'loadgenerator' }],
          traceId: undefined,
        },
        pageSize: 50,
        pageToken: null,
        sortBy: 'duration_asc',
        abortController: expect.any(AbortController),
      });
      expect(observabilityClientMock.fetchTracesAnalytics).not.toHaveBeenCalled();

      expect(findTableList().props('traces')).toEqual(mockResponse.traces);
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      axios.isCancel = jest.fn().mockReturnValue(false);
    });
    it('if fetchTraces fails, it renders an alert and empty list', async () => {
      observabilityClientMock.fetchTraces.mockRejectedValue('error');

      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load traces.' });
      expect(findTableList().exists()).toBe(true);
      expect(findTableList().props('traces')).toEqual([]);
      expect(findAnalytics().exists()).toBe(true);
    });

    it('if fetchTracesAnalytics fails, it renders an alert', async () => {
      observabilityClientMock.fetchTracesAnalytics.mockRejectedValue('error');

      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({
        message: 'Failed to load tracing analytics.',
      });
    });
  });
});
