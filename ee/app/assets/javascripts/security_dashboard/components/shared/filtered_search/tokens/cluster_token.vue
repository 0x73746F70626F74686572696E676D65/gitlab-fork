<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
} from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getClusterAgentsQuery from 'ee/security_dashboard/graphql/queries/cluster_agents.query.graphql';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_CLUSTER_VALUE } from '../../filters/constants';
import eventHub from '../event_hub';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    QuerystringSync,
  },
  inject: ['projectFullPath'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    clusterAgents: {
      query: getClusterAgentsQuery,
      variables() {
        return {
          projectPath: this.projectFullPath,
        };
      },
      update: (data) =>
        data.project?.clusterAgents?.nodes.map((c) => ({
          value: c.name,
          text: c.name,
          gid: c.id,
        })) || [],
      result() {
        // The gids of the cluster agents are required to filter, so in case the querystring contains cluster agents
        // on initialisation, the filters-changed event is emitted once we have the result of the cluster agents query.
        this.emitFiltersChanged();
      },
      error() {
        createAlert({ message: this.$options.i18n.loadingError });
      },
    },
  },
  data() {
    return {
      selected: this.value.data || [ALL_CLUSTER_VALUE],
      clusterAgents: [],
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selected,
      };
    },
    items() {
      return [
        { value: ALL_CLUSTER_VALUE, text: s__('SecurityReports|All clusters') },
        ...this.clusterAgents,
      ];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selected,
        maxOptionsShown: 2,
      });
    },
    isAgentDashboard() {
      return Boolean(this.agentName);
    },
    isLoading() {
      return this.$apollo.queries.clusterAgents.loading;
    },
    clusterAgentIds() {
      return this.clusterAgents.flatMap(({ value, gid }) =>
        this.selected.includes(value) ? [gid] : [],
      );
    },
  },
  methods: {
    emitFiltersChanged() {
      eventHub.$emit('filters-changed', {
        clusterAgentId: this.clusterAgentIds,
      });
    },
    resetSelected() {
      this.selected = [ALL_CLUSTER_VALUE];
      this.emitFiltersChanged();
    },
    updateSelectedFromQS(values) {
      // This happens when we clear the token and re-select `Cluster`
      // to open the dropdown. At that stage we simply want to wait
      // for the user to select new clusters.
      if (!values.length) {
        return;
      }

      this.selected = values;
    },
    toggleSelected(selectedValue) {
      const allClustersSelected = selectedValue === ALL_CLUSTER_VALUE;

      if (this.selected.includes(selectedValue)) {
        this.selected = this.selected.filter((s) => s !== selectedValue);
      } else {
        this.selected = this.selected.filter((s) => s !== ALL_CLUSTER_VALUE);
        this.selected.push(selectedValue);
      }

      if (!this.selected.length || allClustersSelected) {
        this.selected = [ALL_CLUSTER_VALUE];
      }
    },
    isClusterSelected(name) {
      return this.selected.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Cluster'),
    loadingError: s__('SecurityOrchestration|Failed to load cluster agents.'),
  },
};
</script>

<template>
  <querystring-sync querystring-key="cluster" :value="selected" @input="updateSelectedFromQS">
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selected"
      :value="tokenValue"
      v-on="$listeners"
      @select="toggleSelected"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        {{ toggleText }}
      </template>
      <template #suggestions>
        <gl-loading-icon v-if="isLoading" size="sm" />
        <gl-filtered-search-suggestion
          v-for="cluster in items"
          v-else
          :key="cluster.value"
          :value="cluster.value"
        >
          <div class="gl-display-flex gl-align-items-center">
            <gl-icon
              name="check"
              class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
              :class="{ 'gl-invisible': !isClusterSelected(cluster.value) }"
              :data-testid="`cluster-icon-${cluster.value}`"
            />
            {{ cluster.text }}
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
