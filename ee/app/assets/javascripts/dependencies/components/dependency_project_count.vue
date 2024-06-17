<script>
import { GlLink, GlTruncate, GlCollapsibleListbox, GlAvatar } from '@gitlab/ui';
import { debounce } from 'lodash';
import { n__, sprintf } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import { filterBySearchTerm } from '~/analytics/shared/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { extractGroupNamespace } from 'ee/dependencies/store/utils';
import getProjects from '../graphql/projects.query.graphql';
import DependencyProjectCountPopover from './dependency_project_count_popover.vue';
import { SEARCH_MIN_THRESHOLD } from './constants';

const mapItemToListboxFormat = (item) => ({ ...item, value: item.id, text: item.name });

export default {
  name: 'DependencyProjectCount',
  components: {
    GlLink,
    GlTruncate,
    GlCollapsibleListbox,
    GlAvatar,
    DependencyProjectCountPopover,
  },
  inject: ['endpoint', 'belowGroupLimit'],
  props: {
    projectCount: {
      type: Number,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      projects: [],
      searchTerm: '',
    };
  },
  computed: {
    headerText() {
      const projectCount = this.projectCount || 0;
      return sprintf(
        n__(
          'Dependencies|%{projectCount} project',
          'Dependencies|%{projectCount} projects',
          projectCount,
        ),
        { projectCount },
      );
    },
    availableProjects() {
      return filterBySearchTerm(this.projects, this.searchTerm);
    },
    targetId() {
      return `dependency-count-${this.componentId}`;
    },
    searchEnabled() {
      return this.loading || this.projectCount > SEARCH_MIN_THRESHOLD;
    },
  },
  methods: {
    search: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
      this.fetchData();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onHide() {
      this.searchTerm = '';
    },
    onShown() {
      this.fetchData();
    },
    async fetchData() {
      this.loading = true;

      const response = await this.$apollo.query({
        query: getProjects,
        variables: {
          groupFullPath: this.groupNamespace(),
          search: this.searchTerm,
          first: 50,
          includeSubgroups: true,
          sbomComponentId: this.componentId,
        },
      });

      const { nodes } = response.data.group.projects;

      this.loading = false;
      this.projects = nodes.map(mapItemToListboxFormat);
    },
    getEntityId(project) {
      return getIdFromGraphQLId(project.id);
    },
    setSearchTerm(val) {
      this.searchTerm = val;
    },
    getUrl(project) {
      return joinPaths(gon.relative_url_root || '', '/', project.fullPath, '-/dependencies');
    },
    groupNamespace() {
      return extractGroupNamespace(this.endpoint);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <span>
    <gl-collapsible-listbox
      v-if="belowGroupLimit"
      :header-text="headerText"
      :items="availableProjects"
      :searching="loading"
      :searchable="searchEnabled"
      @hidden="onHide"
      @search="search"
      @shown="onShown"
    >
      <template #toggle>
        <span class="md:gl-whitespace-nowrap gl-text-blue-500">
          <gl-truncate
            class="gl-hidden md:gl-inline-flex"
            position="start"
            :text="headerText"
            with-tooltip
          />
        </span>
      </template>
      <template #list-item="{ item }">
        <div class="gl-display-flex">
          <gl-link :href="getUrl(item)" class="gl-hover-text-decoration-none">
            <gl-avatar
              class="gl-mr-2 gl-align-middle"
              :alt="item.name"
              :size="16"
              :entity-id="getEntityId(item)"
              :entity-name="item.name"
              :src="item.avatarUrl"
              :shape="$options.AVATAR_SHAPE_OPTION_RECT"
            />
            <gl-truncate position="start" :text="item.name" with-tooltip />
          </gl-link>
        </div>
      </template>
    </gl-collapsible-listbox>
    <dependency-project-count-popover v-else :target-id="targetId" :target-text="headerText" />
  </span>
</template>
