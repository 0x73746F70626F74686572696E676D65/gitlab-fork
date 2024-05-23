<script>
import { s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import DateRangeToken from '~/vue_shared/components/filtered_search_bar/tokens/daterange_token.vue';
import { SORTING_OPTIONS } from '~/observability/constants';
import {
  PERIOD_FILTER_TOKEN_TYPE,
  SERVICE_NAME_FILTER_TOKEN_TYPE,
  OPERATION_FILTER_TOKEN_TYPE,
  TRACE_ID_FILTER_TOKEN_TYPE,
  DURATION_MS_FILTER_TOKEN_TYPE,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
  STATUS_FILTER_TOKEN_TYPE,
  PERIOD_FILTER_OPTIONS,
  MAX_PERIOD_DAYS,
  filterObjToFilterToken,
  filterTokensToFilterObj,
} from './filters';
import ServiceToken from './service_search_token.vue';
import OperationToken from './operation_search_token.vue';
import AttributeSearchToken from './attribute_search_token.vue';
import BaseSearchToken from './tracing_base_search_token.vue';

export default {
  components: {
    FilteredSearch,
  },
  i18n: {
    searchInputPlaceholder: s__('Tracing|Filter traces'),
  },
  props: {
    attributesFilters: {
      type: Object,
      required: false,
      default: () => {},
    },
    observabilityClient: {
      required: true,
      type: Object,
    },
    initialSort: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      attributesFilterValue: filterObjToFilterToken(this.attributesFilters),
    };
  },
  computed: {
    sortOptions() {
      return [
        {
          id: 1,
          title: s__('Tracing|Duration'),
          sortDirection: {
            ascending: SORTING_OPTIONS.DURATION_ASC,
            descending: SORTING_OPTIONS.DURATION_DESC,
          },
        },
        {
          id: 2,
          title: s__('Tracing|Timestamp'),
          sortDirection: {
            ascending: SORTING_OPTIONS.TIMESTAMP_ASC,
            descending: SORTING_OPTIONS.TIMESTAMP_DESC,
          },
        },
      ];
    },
    availableTokens() {
      return [
        {
          title: s__('Tracing|Time range'),
          icon: 'clock',
          type: PERIOD_FILTER_TOKEN_TYPE,
          token: DateRangeToken,
          operators: OPERATORS_IS,
          unique: true,
          options: PERIOD_FILTER_OPTIONS,
          maxDateRange: MAX_PERIOD_DAYS,
        },
        {
          title: s__('Tracing|Service'),
          type: SERVICE_NAME_FILTER_TOKEN_TYPE,
          token: ServiceToken,
          operators: OPERATORS_IS,
          fetchServices: this.observabilityClient.fetchServices,
        },
        {
          title: s__('Tracing|Operation'),
          type: OPERATION_FILTER_TOKEN_TYPE,
          token: OperationToken,
          operators: OPERATORS_IS,
          fetchOperations: this.observabilityClient.fetchOperations,
        },
        {
          title: s__('Tracing|Trace ID'),
          type: TRACE_ID_FILTER_TOKEN_TYPE,
          token: BaseSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('Tracing|Duration (ms)'),
          type: DURATION_MS_FILTER_TOKEN_TYPE,
          token: BaseSearchToken,
          operators: [
            { value: '>', description: s__('Tracing|longer than') },
            { value: '<', description: s__('Tracing|shorter than') },
          ],
        },
        {
          title: s__('Tracing|Attribute'),
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('Tracing|Status'),
          type: STATUS_FILTER_TOKEN_TYPE,
          token: BaseSearchToken,
          operators: OPERATORS_IS,
          options: [
            { value: 'ok', title: s__('Tracing|Ok') },
            { value: 'error', title: s__('Tracing|Error') },
          ],
        },
      ];
    },
  },
  methods: {
    onAttributesFilters(attributesFilters) {
      this.attributesFilterValue = attributesFilters;
      this.submitFilter();
    },
    submitFilter() {
      this.$emit('filter', {
        attributes: filterTokensToFilterObj(this.attributesFilterValue),
      });
    },
  },
};
</script>

<template>
  <div class="vue-filtered-search-bar-container gl-border-t-none gl-my-6">
    <filtered-search
      recent-searches-storage-key="recent-tracing-filter-search"
      :initial-sort-by="initialSort"
      namespace="tracing-list-filtered-search"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      :tokens="availableTokens"
      :initial-filter-value="attributesFilterValue"
      terms-as-tokens
      :sort-options="sortOptions"
      sync-filter-and-sort
      @onFilter="onAttributesFilters"
      @onSort="$emit('sort', $event)"
    />
  </div>
</template>
