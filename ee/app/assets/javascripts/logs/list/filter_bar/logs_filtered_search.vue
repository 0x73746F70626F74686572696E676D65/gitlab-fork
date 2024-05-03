<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { s__ } from '~/locale';
import {
  OPERATORS_IS_NOT,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  SERVICE_NAME_FILTER_TOKEN_TYPE,
  SEVERITY_NAME_FILTER_TOKEN_TYPE,
  SEVERITY_NUMBER_FILTER_TOKEN_TYPE,
  TRACE_ID_FILTER_TOKEN_TYPE,
  SPAN_ID_FILTER_TOKEN_TYPE,
  FINGERPRINT_FILTER_TOKEN_TYPE,
  TRACE_FLAGS_FILTER_TOKEN_TYPE,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
  RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE,
  filterTokensToFilterObj,
  filterObjToFilterToken,
} from './filters';
import AttributeSearchToken from './attribute_search_token.vue';

// TODO get levels from API https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2782
const SEVERITY_LEVEL_OPTIONS = ['trace', 'debug', 'info', 'warn', 'error', 'fatal'];

export default {
  components: {
    DateRangeFilter,
    FilteredSearch,
  },
  props: {
    dateRangeFilter: {
      type: Object,
      required: true,
    },
    attributesFilters: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  i18n: {
    searchInputPlaceholder: s__('ObservabilityLogs|Search logs...'),
  },
  data() {
    return {
      attributesFilterValue: filterObjToFilterToken(this.attributesFilters),
      dateRangeFilterValue: this.dateRangeFilter,
    };
  },
  computed: {
    availableTokens() {
      return [
        {
          title: s__('ObservabilityLogs|Service'),
          type: SERVICE_NAME_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
        },
        {
          title: s__('ObservabilityLogs|Severity'),
          type: SEVERITY_NAME_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
          options: SEVERITY_LEVEL_OPTIONS.map((level) => ({
            value: level,
            title: level,
          })),
        },
        {
          title: s__('ObservabilityLogs|Severity Number'),
          type: SEVERITY_NUMBER_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
        },
        {
          title: s__('ObservabilityLogs|Trace ID'),
          type: TRACE_ID_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Span ID'),
          type: SPAN_ID_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Fingerprint'),
          type: FINGERPRINT_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Trace Flags'),
          type: TRACE_FLAGS_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
        },
        {
          title: s__('ObservabilityLogs|Attribute'),
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Resource Attribute'),
          type: RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
      ];
    },
  },
  methods: {
    onDateRangeSelected({ value, startDate, endDate }) {
      this.dateRangeFilterValue = { value, startDate, endDate };
      this.submitFilter();
    },
    onAttributesFilters(attributesFilters) {
      this.attributesFilterValue = attributesFilters;
      this.submitFilter();
    },
    submitFilter() {
      this.$emit('filter', {
        dateRange: this.dateRangeFilterValue,
        attributes: filterTokensToFilterObj(this.attributesFilterValue),
      });
    },
  },
};
</script>

<template>
  <div
    class="gl-py-5 gl-px-3 gl-bg-gray-10 gl-border-b-1 gl-border-b-solid gl-border-t-1 gl-border-t-solid gl-border-gray-100"
  >
    <filtered-search
      class="filtered-search-box gl-display-flex gl-border-none"
      recent-searches-storage-key="recent-logs-filter-search"
      namespace="logs-details-filtered-search"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      :tokens="availableTokens"
      :initial-filter-value="attributesFilterValue"
      terms-as-tokens
      @onFilter="onAttributesFilters"
    />

    <hr class="gl-my-3" />

    <date-range-filter
      :selected="dateRangeFilterValue"
      @onDateRangeSelected="onDateRangeSelected"
    />
  </div>
</template>
