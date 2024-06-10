import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { filterObjToFilterToken } from 'ee/metrics/list/filters';
import MetricsTable from 'ee/metrics/list/metrics_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MetricsList from 'ee/metrics/list/metrics_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockClient } from 'helpers/mock_observability_client';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { mockMetrics } from './mock_data';

jest.mock('~/alert');

describe('MetricsComponent', () => {
  let wrapper;
  let observabilityClientMock;

  const mockAvailableAttributes = ['attr-1', 'attr-2', 'attr-3'];

  const mockResponse = {
    metrics: [...mockMetrics],
    all_available_attributes: mockAvailableAttributes,
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const findInfiniteScrolling = () => wrapper.findComponent(GlInfiniteScroll);
  const findMetricsTable = () => findInfiniteScrolling().getComponent(MetricsTable);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const setFilters = async (filters) => {
    findFilteredSearch().vm.$emit('onFilter', filterObjToFilterToken(filters));
    await waitForPromises();
  };

  // eslint-disable-next-line no-console
  console.error = jest.fn();

  const mountComponent = async () => {
    wrapper = shallowMountExtended(MetricsList, {
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
    observabilityClientMock.fetchMetrics.mockResolvedValue(mockResponse);
  });

  describe('initial metrics fetching', () => {
    it('only renders the loading indicator while fetching metrics', () => {
      mountComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findInfiniteScrolling().exists()).toBe(false);
      expect(findFilteredSearch().exists()).toBe(false);

      expect(observabilityClientMock.fetchMetrics).toHaveBeenCalledWith({
        filters: { search: undefined },
        limit: 50,
      });
    });

    describe('when done', () => {
      beforeEach(async () => {
        await mountComponent();
      });
      it('does not render the loading indicator', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('renders the search bar', () => {
        expect(findFilteredSearch().exists()).toBe(true);
      });

      it('renders renders infinite scrolling list', () => {
        expect(findInfiniteScrolling().exists()).toBe(true);
        expect(findInfiniteScrolling().props('fetchedItems')).toBe(mockResponse.metrics.length);
        expect(
          findInfiniteScrolling().find('[data-testid="metrics-infinite-scrolling-legend"]').text(),
        ).toBe('');
      });

      it('renders the metrics table within the infinite-scrolling', () => {
        expect(findMetricsTable().exists()).toBe(true);
        expect(findMetricsTable().props('metrics')).toEqual(mockResponse.metrics);
      });

      it('renders the header', () => {
        expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Metrics');
        expect(wrapper.find('header').text()).toBe(
          'Track health data from your systems. Send metric data to this project using OpenTelemetry. Learn more.',
        );
      });
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      setWindowLocation('?search=foo+bar&attribute[]=test.attr');
      await mountComponent();
    });

    it('renders FilteredSeach with initial filters parsed from window.location', () => {
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(
        filterObjToFilterToken({
          search: [{ value: 'foo bar' }],
          attribute: [{ value: 'test.attr', operator: '=' }],
        }),
      );
    });

    it('renders FilteredSeach with Attribute tokens', () => {
      const tokens = findFilteredSearch()
        .props('tokens')
        .find(({ type }) => type === 'attribute');

      expect(tokens).toBeDefined();
      expect(tokens.options).toEqual([
        { title: 'attr-1', value: 'attr-1' },
        { title: 'attr-2', value: 'attr-2' },
        { title: 'attr-3', value: 'attr-3' },
      ]);
    });

    it('renders UrlSync and sets query prop', () => {
      expect(findUrlSync().props('query')).toEqual({
        search: 'foo bar',
        attribute: ['test.attr'],
        'not[attribute]': null,
      });
    });

    it('fetches metrics with filters and limit', () => {
      expect(observabilityClientMock.fetchMetrics).toHaveBeenLastCalledWith({
        filters: {
          search: [{ value: 'foo bar' }],
          attribute: [{ value: 'test.attr', operator: '=' }],
        },
        limit: 50,
      });
    });

    describe('on search submit', () => {
      beforeEach(async () => {
        await setFilters({
          search: [{ value: 'search query' }],
          attribute: [{ value: 'updated.attr.filter', operator: '=' }],
        });
      });

      it('hides the loading indicator when done', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findFilteredSearch().exists()).toBe(true);
        expect(findInfiniteScrolling().exists()).toBe(true);
        expect(findMetricsTable().exists()).toBe(true);
      });

      it('updates the query on search submit', () => {
        expect(findUrlSync().props('query')).toEqual({
          search: 'search query',
          attribute: ['updated.attr.filter'],
          'not[attribute]': null,
        });
      });

      it('fetches metrics with updated filters', () => {
        expect(observabilityClientMock.fetchMetrics).toHaveBeenLastCalledWith({
          filters: {
            search: [{ value: 'search query' }],
            attribute: [{ value: 'updated.attr.filter', operator: '=' }],
          },
          limit: 50,
        });
      });

      it('updates FilteredSearch initialFilters', () => {
        expect(findFilteredSearch().props('initialFilterValue')).toEqual(
          filterObjToFilterToken({
            search: [{ value: 'search query' }],
            attribute: [{ value: 'updated.attr.filter', operator: '=' }],
          }),
        );
      });
    });
  });

  describe('error handling', () => {
    it('if fetchMetrics fails, it renders an alert and empty list', async () => {
      observabilityClientMock.fetchMetrics.mockRejectedValue('error');
      await mountComponent();

      expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load metrics.' });
      expect(findMetricsTable().exists()).toBe(true);
      expect(findMetricsTable().props('metrics')).toEqual([]);
    });
  });

  describe('on metric-clicked', () => {
    let visitUrlMock;

    const mockMetricSelected = mockMetrics[0];

    beforeEach(async () => {
      setWindowLocation('http://test.host/projectX/-/metrics?search=query');
      visitUrlMock = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});

      await mountComponent();
    });

    it('redirects to the details url', () => {
      findMetricsTable().vm.$emit('metric-clicked', { metricId: mockMetricSelected.name });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith(
        `http://test.host/projectX/-/metrics/${mockMetricSelected.name}?type=${mockMetricSelected.type}`,
        false,
      );
    });

    it('opens a new tab if clicked with meta key', () => {
      findMetricsTable().vm.$emit('metric-clicked', {
        metricId: mockMetricSelected.name,
        clickEvent: { metaKey: true },
      });

      expect(visitUrlMock).toHaveBeenCalledTimes(1);
      expect(visitUrlMock).toHaveBeenCalledWith(
        `http://test.host/projectX/-/metrics/${mockMetricSelected.name}?type=${mockMetricSelected.type}`,
        true,
      );
    });

    it('does not redirect if metric type cannot be found', () => {
      findMetricsTable().vm.$emit('metric-clicked', {
        metricId: 'unknown-metric',
      });
      expect(visitUrlMock).not.toHaveBeenCalled();
    });
  });
});
