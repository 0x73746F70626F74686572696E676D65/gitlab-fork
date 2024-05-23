import OperationToken from 'ee/tracing/list/filter_bar/operation_search_token.vue';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import DateRangeToken from '~/vue_shared/components/filtered_search_bar/tokens/daterange_token.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceToken from 'ee/tracing/list/filter_bar/service_search_token.vue';
import AttributeSearchToken from 'ee/tracing/list/filter_bar/attribute_search_token.vue';
import TracingListFilteredSearch from 'ee/tracing/list/filter_bar/tracing_filtered_search.vue';
import TracingBaseSearchToken from 'ee/tracing/list/filter_bar/tracing_base_search_token.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { filterObjToFilterToken } from 'ee/tracing/list/filter_bar/filters';

describe('TracingListFilteredSearch', () => {
  let wrapper;
  let observabilityClientMock;

  const defaultProps = {
    attributesFilters: {
      period: [{ operator: '=', value: '1h' }],
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

  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const getTokens = () => findFilteredSearch().props('tokens');

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('sets filtered-search initialFilterValue prop correctly', () => {
    expect(findFilteredSearch().props('initialFilterValue')).toEqual(
      filterObjToFilterToken(defaultProps.attributesFilters),
    );
  });

  it('emits submit event on filtered search filter', async () => {
    const filterObj = {
      period: [{ operator: '=', value: '24h' }],
      service: [{ operator: '=', value: 'some-service' }],
    };

    const filterTokens = filterObjToFilterToken(filterObj);
    await findFilteredSearch().vm.$emit('onFilter', filterTokens);

    expect(wrapper.emitted('filter')).toEqual([
      [
        {
          attributes: filterObj,
        },
      ],
    ]);
    expect(findFilteredSearch().props('initialFilterValue')).toEqual(filterTokens);
  });

  it('sets the default period filter if not specified', async () => {
    await findFilteredSearch().vm.$emit('onFilter', filterObjToFilterToken({}));

    expect(wrapper.emitted('filter')).toEqual([
      [{ attributes: { period: [{ operator: '=', value: '1h' }] } }],
    ]);
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
    it('configure the date range token', () => {
      const tokens = getTokens();
      const token = tokens.find((t) => t.type === 'period');
      expect(token.token).toBe(DateRangeToken);
      expect(token.maxDateRange).toBe(7);
      expect(token.options.map(({ value }) => value)).toEqual([
        '5m',
        '15m',
        '30m',
        '1h',
        '4h',
        '12h',
        '24h',
        '7d',
      ]);
    });

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
