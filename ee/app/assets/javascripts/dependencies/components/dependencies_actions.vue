<script>
import { GlSorting } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { omit } from 'lodash';
import { __ } from '~/locale';
import { setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import { NAMESPACE_PROJECT } from '../constants';
import { DEPENDENCY_LIST_TYPES } from '../store/constants';
import {
  SORT_FIELDS_PROJECT,
  SORT_FIELDS_GROUP,
  SORT_ASCENDING,
  SORT_FIELD_LICENSE,
} from '../store/modules/list/constants';

export default {
  i18n: {
    sortDirectionLabel: __('Sort direction'),
  },
  name: 'DependenciesActions',
  components: {
    GlSorting,
    GroupDependenciesFilteredSearch,
  },
  inject: ['namespaceType', 'belowGroupLimit'],
  props: {
    namespace: {
      type: String,
      required: true,
      validator: (value) =>
        Object.values(DEPENDENCY_LIST_TYPES).some(({ namespace }) => value === namespace),
    },
  },
  computed: {
    isSortAscending() {
      return this.sortOrder === SORT_ASCENDING;
    },
    ...mapState({
      sortField(state) {
        return state[this.namespace].sortField;
      },
      sortOrder(state) {
        return state[this.namespace].sortOrder;
      },
    }),
    sortFieldName() {
      return this.sortFields[this.sortField];
    },
    sortFields() {
      const groupFields = this.belowGroupLimit
        ? SORT_FIELDS_GROUP
        : omit(SORT_FIELDS_GROUP, SORT_FIELD_LICENSE);

      return this.isProjectNamespace ? SORT_FIELDS_PROJECT : groupFields;
    },
    sortOptions() {
      return Object.keys(this.sortFields).map((key) => ({
        text: this.sortFields[key],
        value: key,
      }));
    },
    isProjectNamespace() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
  },
  methods: {
    ...mapActions({
      setSortField(dispatch, field) {
        this.clearCursorParam();
        dispatch(`${this.namespace}/setSortField`, field);
      },
      toggleSortOrder(dispatch) {
        this.clearCursorParam();
        dispatch(`${this.namespace}/toggleSortOrder`);
      },
    }),
    clearCursorParam() {
      updateHistory({ url: setUrlParams({ cursor: null }) });
    },
  },
};
</script>

<template>
  <div
    class="gl-display-flex gl-p-5 gl-bg-gray-10 gl-border-t-1 gl-border-t-solid gl-border-gray-100 gl-align-items-flex-start"
  >
    <group-dependencies-filtered-search
      v-if="!isProjectNamespace"
      class="gl-mr-3 gl-flex-grow-1 gl-min-w-0"
    />
    <gl-sorting
      :text="sortFieldName"
      :is-ascending="isSortAscending"
      :sort-direction-tool-tip="$options.i18n.sortDirectionLabel"
      :sort-options="sortOptions"
      :sort-by="sortField"
      class="gl-ml-auto"
      @sortDirectionChange="toggleSortOrder"
      @sortByChange="setSortField"
    />
  </div>
</template>
