<script>
import { GlAlert, GlTabs, GlTab, GlBadge } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { AGENT_MAPPING_STATUS_MAPPED } from '../constants';
import AgentsTable from './agents_table.vue';
import GetAgentsWithMappingStatusQuery from './get_agents_with_mapping_status_query.vue';

const NO_ALLOWED_AGENTS_MESSAGE = s__(
  'Workspaces|This group has no available agents. Select the %{strongStart}All agents%{strongEnd} tab and allow at least one agent.',
);
const NO_AGENTS_MESSAGE = s__('Workspaces|This group has no agents. Start by creating an agent.');
const ERROR_LOADING_AVAILABLE_AGENTS_MESSAGE = s__(
  'Workspaces|Could not load available agents. Refresh the page to try again.',
);

export default {
  components: {
    GlAlert,
    GlBadge,
    GlTabs,
    GlTab,
    AgentsTable,
    GetAgentsWithMappingStatusQuery,
  },
  inject: {
    namespace: {
      default: '',
    },
  },
  data() {
    return {
      agents: [],
      errorMessage: '',
    };
  },
  computed: {
    allowedAgents() {
      return this.agents.filter((agent) => agent.mappingStatus === AGENT_MAPPING_STATUS_MAPPED);
    },
    allowedAgentsTableEmptyMessage() {
      return this.agents.length
        ? sprintf(
            NO_ALLOWED_AGENTS_MESSAGE,
            { strongStart: '<strong>', strongEnd: '</strong>' },
            false,
          )
        : NO_AGENTS_MESSAGE;
    },
  },
  methods: {
    onQueryResult({ agents }) {
      this.agents = agents;
    },
    onErrorResult() {
      this.errorMessage = ERROR_LOADING_AVAILABLE_AGENTS_MESSAGE;
    },
  },
  NO_AGENTS_MESSAGE,
};
</script>
<template>
  <get-agents-with-mapping-status-query
    :namespace="namespace"
    @result="onQueryResult"
    @error="onErrorResult"
  >
    <template #default="{ loading }">
      <div>
        <gl-alert v-if="errorMessage" class="mb-3" variant="danger" :dismissible="false">
          {{ errorMessage }}
        </gl-alert>
        <gl-tabs lazy>
          <gl-tab data-testid="allowed-agents-tab">
            <template #title>
              <span>{{ s__('Workspaces|Allowed Agents') }}</span>
              <gl-badge size="sm" class="gl-tab-counter-badge">{{ allowedAgents.length }}</gl-badge>
              <span class="sr-only">{{ __('agents') }}</span>
            </template>
            <agents-table
              v-if="!errorMessage"
              data-testid="allowed-agents-table"
              :agents="allowedAgents"
              :is-loading="loading"
              :empty-state-message="allowedAgentsTableEmptyMessage"
            />
          </gl-tab>
          <gl-tab data-testid="all-agents-tab">
            <template #title>
              <span>{{ s__('Workspaces|All agents') }}</span>
              <gl-badge size="sm" class="gl-tab-counter-badge">{{ agents.length }}</gl-badge>
              <span class="sr-only">{{ __('agents') }}</span>
            </template>
            <agents-table
              v-if="!errorMessage"
              data-testid="all-agents-table"
              :agents="agents"
              :is-loading="loading"
              display-mapping-status
              :empty-state-message="$options.NO_AGENTS_MESSAGE"
            />
          </gl-tab>
        </gl-tabs>
      </div>
    </template>
  </get-agents-with-mapping-status-query>
</template>
