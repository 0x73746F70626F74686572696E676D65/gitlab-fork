<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getProjects from 'ee/dependencies/graphql/projects.query.graphql';
import QuerystringSync from '../../filters/querystring_sync.vue';
import eventHub from '../event_hub';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    QuerystringSync,
  },
  inject: ['groupFullPath'],
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
    return {
      projects: [],
      selectedProjectIds: [],
      isLoadingProjects: true,
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
        const { data } = await this.$apollo.query({
          query: getProjects,
          variables: {
            groupFullPath: this.groupNamespace,
            search: '',
            first: 50,
            includeSubgroups: true,
          },
        });

        this.projects = data.group.projects.nodes.map((p) => ({
          ...p,
          rawId: getIdFromGraphQLId(p.id),
        }));
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
      :multi-select-values="selectedProjectNames"
      :value="tokenValue"
      v-on="$listeners"
      @complete="onComplete"
      @destroy="resetSelected"
      @select="toggleSelectedProject"
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
