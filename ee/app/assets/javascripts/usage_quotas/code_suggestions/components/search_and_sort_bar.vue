<script>
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  FILTERED_SEARCH_TERM,
  TOKEN_TYPE_PROJECT,
  TOKEN_TYPE_GROUP_INVITE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { processFilters } from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';

export default {
  name: 'SearchAndSortBar',
  components: {
    FilteredSearchBar,
  },
  inject: { fullPath: { default: '' } },
  props: {
    sortOptions: {
      type: Array,
      default: () => [],
      required: false,
    },
    tokens: {
      type: Array,
      default: () => [],
      required: false,
    },
  },
  data() {
    return {
      search: undefined,
    };
  },
  methods: {
    handleFilter(filterOptions) {
      const {
        [FILTERED_SEARCH_TERM]: searchFilters = [],
        [TOKEN_TYPE_PROJECT]: [{ value: filterByProjectId } = {}] = [],
        [TOKEN_TYPE_GROUP_INVITE]: [{ value: filterByGroupInvite } = {}] = [],
      } = processFilters(filterOptions);
      const search = this.processSearchFilters(searchFilters);
      this.$emit('onFilter', { search, filterByProjectId, filterByGroupInvite });
    },
    handleSort(sortValue) {
      this.$emit('onSort', sortValue);
    },
    processSearchFilters(searchFilters) {
      if (searchFilters.length === 0) return undefined;
      return searchFilters.reduce((acc, { value }) => {
        if (!acc && !value) return undefined;
        if (!value) return acc;
        return `${acc} ${value}`.trim();
      }, '');
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-bg-gray-10 gl-p-5 gl-pt-0 gl-gap-3">
    <filtered-search-bar
      class="gl-flex-grow-1"
      :namespace="fullPath"
      :tokens="tokens"
      :search-input-placeholder="__('Filter users')"
      :sort-options="sortOptions"
      @onFilter="handleFilter"
      @onSort="handleSort"
    />
  </div>
</template>
