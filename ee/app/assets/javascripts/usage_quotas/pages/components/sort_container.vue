<script>
import { GlSorting } from '@gitlab/ui';
import { __ } from '~/locale';
import { SORT_OPTION } from '../constants';

export default {
  name: 'SortContainer',
  components: {
    GlSorting,
  },
  sortOptions: [
    {
      value: SORT_OPTION.CREATED,
      text: __('Created Date'),
    },
    {
      value: SORT_OPTION.UPDATED,
      text: __('Updated Date'),
    },
  ],
  data() {
    return {
      sortBy: SORT_OPTION.CREATED,
      sortAscending: false,
    };
  },
  computed: {
    sortExpresion() {
      if (!this.sortBy) return null;
      return [this.sortBy, this.sortAscending ? 'ASC' : 'DESC'].join('_');
    },
  },
  methods: {
    onSortByChange(value) {
      this.sortBy = value;
      this.onUpdate();
    },
    onSortDirectionChange(value) {
      this.sortAscending = value;
      this.onUpdate();
    },
    onUpdate() {
      this.$emit('update', this.sortExpresion);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-4 gl-items-center">
    <label for="sort" class="gl-m-0 gl-text-nowrap">{{ __('Sort by') }}</label>
    <gl-sorting
      id="sort"
      data-test-id="gl-sorting"
      :sort-options="$options.sortOptions"
      :sort-by="sortBy"
      :is-ascending="sortAscending"
      @sortByChange="onSortByChange"
      @sortDirectionChange="onSortDirectionChange"
    />
  </div>
</template>
