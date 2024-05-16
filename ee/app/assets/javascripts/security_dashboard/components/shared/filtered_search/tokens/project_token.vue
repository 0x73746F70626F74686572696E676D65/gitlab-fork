<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { createAlert } from '~/alert';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import groupProjectsQuery from 'ee/security_dashboard/graphql/queries/group_projects.query.graphql';
import instanceProjectsQuery from 'ee/security_dashboard/graphql/queries/instance_projects.query.graphql';
import QuerystringSync from '../../filters/querystring_sync.vue';
import eventHub from '../event_hub';

const QUERIES = {
  [DASHBOARD_TYPES.GROUP]: groupProjectsQuery,
  [DASHBOARD_TYPES.INSTANCE]: instanceProjectsQuery,
};

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    QuerystringSync,
  },
  inject: ['groupFullPath', 'dashboardType'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const data = this.value?.data;
    let selectedProjectIds = [];

    if (Array.isArray(data)) {
      selectedProjectIds = data.map(Number);
    }

    return {
      projects: [],
      selectedProjectIds,
      isLoadingProjects: false,
      searchTerm: '',
    };
  },
  computed: {
    groupNamespace() {
      return this.groupFullPath;
    },
    selectedProjects() {
      return this.projects.filter(({ rawId }) => this.selectedProjectIds.includes(rawId));
    },
    selectedProjectNames() {
      return this.selectedProjects.map(({ name }) => name);
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedProjectNames,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.projects.map((p) => ({ text: p.name, id: p.rawId })),
        selected: this.selectedProjectIds,
        maxOptionsShown: 1, // Project names can be long. Limit to 1.
      });
    },
  },
  created() {
    this.fetchProjects();
  },
  methods: {
    async fetchProjects() {
      try {
        this.isLoadingProjects = true;

        const { data } = await this.$apollo.query({
          query: QUERIES[this.dashboardType],
          variables: {
            fullPath: this.groupNamespace,
            search: this.searchTerm,
            pageSize: 100,
          },
        });

        this.projects = data[this.dashboardType].projects.edges.map(({ node }) => ({
          ...node,
          rawId: getIdFromGraphQLId(node.id),
        }));

        this.projects.sort((p1, p2) => p1.name.localeCompare(p2.name));
      } catch {
        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      } finally {
        this.isLoadingProjects = false;
      }
    },
    resetSelected() {
      this.selectedProjectIds = [];
      this.emitFiltersChanged();
    },
    isProjectSelected(project) {
      return this.selectedProjectIds.some((id) => id === project.rawId);
    },
    toggleSelectedProject(project) {
      if (this.isProjectSelected(project)) {
        this.selectedProjectIds = this.selectedProjectIds.filter((id) => id !== project.rawId);
      } else {
        this.selectedProjectIds.push(project.rawId);
      }
    },
    onComplete() {
      this.emitFiltersChanged();
    },
    emitFiltersChanged() {
      // the dropdown shows a list of project names but we need to emit the project ids for filtering
      eventHub.$emit('filters-changed', { projectId: [...this.selectedProjectIds] });
    },
    updateSelectedFromQS(ids) {
      this.selectedProjectIds = ids.map((id) => Number(id));
      this.emitFiltersChanged();
    },
    setSearchTerm: debounce(function debouncedSetSearchTerm({ data }) {
      // when the user is doing a search, we receive a string. If they
      // click on dropdown items we receive an array. For this reason, we can
      // safely ignore non-string data.
      if (typeof data === 'string') {
        this.searchTerm = data.length >= 3 ? data : '';

        // since apollo caches the results, we can trigger a fetch every time the search term changes
        // and requests will only be made if there is no existing data for the current term
        this.fetchProjects();
      }
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
  },
  i18n: {
    label: __('Project'),
    fetchErrorMessage: s__(
      'Dependencies|There was an error fetching the projects for this group. Please try again later.',
    ),
  },
};
</script>

<template>
  <querystring-sync
    querystring-key="projectId"
    :value="selectedProjectIds"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedProjectIds"
      :value="tokenValue"
      v-on="$listeners"
      @complete="onComplete"
      @destroy="resetSelected"
      @select="toggleSelectedProject"
      @input="setSearchTerm"
    >
      <template #view>
        {{ toggleText }}
      </template>
      <template #suggestions>
        <gl-loading-icon v-if="isLoadingProjects" size="sm" />
        <template v-else>
          <gl-filtered-search-suggestion
            v-for="project in projects"
            :key="project.id"
            :value="project"
          >
            <div class="gl-flex gl-items-center">
              <gl-icon
                v-if="config.multiSelect"
                name="check"
                class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
                :class="{ 'gl-invisible': !isProjectSelected(project) }"
              />
              {{ project.name }}
            </div>
          </gl-filtered-search-suggestion>
        </template>
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
