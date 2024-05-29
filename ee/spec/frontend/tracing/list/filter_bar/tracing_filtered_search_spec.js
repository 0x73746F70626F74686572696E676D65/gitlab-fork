import { nextTick } from 'vue';
import OperationToken from 'ee/tracing/list/filter_bar/operation_search_token.vue';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceToken from 'ee/tracing/list/filter_bar/service_search_token.vue';
import AttributeSearchToken from 'ee/tracing/list/filter_bar/attribute_search_token.vue';
import TracingListFilteredSearch from 'ee/tracing/list/filter_bar/tracing_filtered_search.vue';
import TracingBaseSearchToken from 'ee/tracing/list/filter_bar/tracing_base_search_token.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { filterObjToFilterToken } from 'ee/tracing/list/filter_bar/filters';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';

describe('TracingListFilteredSearch', () => {
  let wrapper;
  let observabilityClientMock;

  const defaultProps = {
    dateRangeFilter: {
      endDate: new Date('2020-07-06T00:00:00.000Z'),
      startDarte: new Date('2020-07-05T23:00:00.000Z'),
      value: '1h',
    },
    attributesFilters: {
      service: [{ operator: '=', value: 'example-service' }],
    },
    initialSort: 'duration_desc',
  };

  beforeEach(() => {
    observabilityClientMock = createMockClient();

    wrapper = shallowMountExtended(TracingListFilteredSearch, {
      propsData: {
        ...defaultProps,
        observabilityClient: observabilityClientMock,
      },
    });
  });

  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const getTokens = () => findFilteredSearch().props('tokens');

  describe('date range filter', () => {
    it('renders the date range filter', () => {
      expect(findDateRangeFilter().exists()).toBe(true);
    });

    it('sets the selected date range', () => {
      expect(findDateRangeFilter().props('selected')).toEqual(defaultProps.dateRangeFilter);
    });

    it('emits the filter event when the date range is changed', async () => {
      const dateRange = {
        value: '24h',
        startDate: new Date('2022-01-01'),
        endDate: new Date('2022-01-02'),
      };

      findDateRangeFilter().vm.$emit('onDateRangeSelected', dateRange);
      await nextTick();

      expect(wrapper.emitted('filter')).toEqual([
        [
          {
            dateRange,
            attributes: expect.any(Object),
          },
        ],
      ]);
      expect(findDateRangeFilter().props('selected')).toEqual(dateRange);
    });
  });

  describe('attributes filters', () => {
    it('renders the FilteredSearch', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('sets the initial attributes filter by converting it to tokens', () => {
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(
        filterObjToFilterToken(defaultProps.attributesFilters),
      );
    });

    it('emits the filter event when the search is submitted', async () => {
      const filterObj = {
        service: [{ operator: '=', value: 'some-service' }],
      };

      const filterTokens = filterObjToFilterToken(filterObj);

      findFilteredSearch().vm.$emit('onFilter', filterTokens);
      await nextTick();

      expect(wrapper.emitted('filter')).toEqual([
        [
          {
            dateRange: expect.any(Object),
            attributes: filterObj,
          },
        ],
      ]);
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(filterTokens);
    });
  });

  describe('sorting', () => {
    it('sets initialSortBy prop correctly', () => {
      expect(findFilteredSearch().props('initialSortBy')).toBe(wrapper.props('initialSort'));
    });

    it('emits sort event onSort', () => {
      findFilteredSearch().vm.$emit('onSort', 'duration_desc');

      expect(wrapper.emitted('sort')).toStrictEqual([['duration_desc']]);
    });
  });

  describe('tokens', () => {
    it('configure the attribute token', () => {
      const tokens = getTokens();
      const attributeToken = tokens.find((t) => t.type === 'attribute');
      expect(attributeToken.token).toBe(AttributeSearchToken);
    });

    it('configure the service token', () => {
      const tokens = getTokens();
      const serviceToken = tokens.find((t) => t.type === 'service-name');
      expect(serviceToken.token).toBe(ServiceToken);
      expect(serviceToken.fetchServices).toBe(observabilityClientMock.fetchServices);
    });

    it('configure the operation token', () => {
      const tokens = getTokens();
      const operationToken = tokens.find((t) => t.type === 'operation');
      expect(operationToken.token).toBe(OperationToken);
      expect(operationToken.fetchOperations).toBe(observabilityClientMock.fetchOperations);
    });

    it('configure the trace-id token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'trace-id').token).toBe(TracingBaseSearchToken);
    });

    it('configure the status token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'status').token).toBe(TracingBaseSearchToken);
    });

    it('configure the duration token', () => {
      const tokens = getTokens();
      expect(tokens.find((t) => t.type === 'duration-ms').token).toBe(TracingBaseSearchToken);
    });
  });
});
