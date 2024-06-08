<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce, uniqBy } from 'lodash';
import produce from 'immer';
import { __ } from '~/locale';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  i18n: {
    projectDropdownHeader: __('Select projects'),
    selectAllLabel: __('Select all'),
    clearAllLabel: __('Clear all'),
  },
  name: 'GroupProjectsDropdown',
  components: {
    GlCollapsibleListbox,
  },
  apollo: {
    projects: {
      query: getGroupProjects,
      variables() {
        return {
          fullPath: this.groupFullPath,
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        return uniqBy([...this.projects, ...data.group.projects.nodes], 'id');
      },
      result({ data }) {
        this.projectsPageInfo = data?.group?.projects?.pageInfo || {};
      },
      error() {
        this.$emit('projects-query-error');
      },
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupFullPath: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'left',
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      projectsPageInfo: {},
      searchTerm: '',
      projects: [],
    };
  },
  computed: {
    formattedSelectedProjectsIds() {
      return this.multiple ? this.selected : [this.selected];
    },
    existingFormattedSelectedProjectsIds() {
      if (this.multiple) {
        return this.selected.filter((id) => this.projectsIds.includes(id));
      }

      return this.selected;
    },
    dropdownPlaceholder() {
      return renderMultiSelectText({
        selected: this.formattedSelectedProjectsIds,
        items: this.projectItems,
        itemTypeName: __('projects'),
        useAllSelected: !this.hasNextPage,
      });
    },
    loading() {
      return this.$apollo.queries.projects.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.projectsPageInfo.hasNextPage;
    },
    projectItems() {
      return this.projects?.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    projectListBoxItems() {
      return this.projects
        .map(({ id, name }) => ({ text: name, value: id }))
        .filter(({ text }) => text.toLowerCase().includes(this.searchTerm.toLowerCase()));
    },
    projectsIds() {
      return this.projects.map(({ id }) => id);
    },
    resetButtonLabel() {
      return this.multiple ? this.$options.i18n.clearAllLabel : '';
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchMoreGroupProjects() {
      this.$apollo.queries.projects
        .fetchMore({
          variables: {
            fullPath: this.groupFullPath,
            after: this.projectsPageInfo.endCursor,
          },
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.group.projects.nodes = [
                ...previousResult.group.projects.nodes,
                ...draftData.group.projects.nodes,
              ];
            });
          },
        })
        .catch(() => {
          this.$emit('projects-query-error');
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectProjects(selected) {
      const ids = this.multiple ? selected : [selected];
      const selectedProjects = this.projects.filter(({ id }) => ids.includes(id));
      const payload = this.multiple ? selectedProjects : selectedProjects[0];
      this.$emit('select', payload);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    is-check-centered
    searchable
    fluid-width
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="$options.i18n.projectDropdownHeader"
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="loading"
    :reset-button-label="resetButtonLabel"
    :show-select-all-button-label="$options.i18n.selectAllLabel"
    :searching="searching"
    :selected="existingFormattedSelectedProjectsIds"
    :placement="placement"
    :items="projectListBoxItems"
    :toggle-text="dropdownPlaceholder"
    @bottom-reached="fetchMoreGroupProjects"
    @search="debouncedSearch"
    @reset="selectProjects([])"
    @select="selectProjects"
    @select-all="selectProjects(projectsIds)"
  />
</template>
