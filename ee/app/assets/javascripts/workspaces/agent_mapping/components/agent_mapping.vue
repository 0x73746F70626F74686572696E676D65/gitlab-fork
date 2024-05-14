<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import AgentsTable from './agents_table.vue';
import GetAvailableAgentsQuery from './get_available_agents_query.vue';

const NO_ALLOWED_AGENTS_MESSAGE = s__(
  'Workspaces|This group has no available agents. Select the All agents tab and allow at least one agent.',
);
const ERROR_LOADING_AVAILABLE_AGENTS_MESSAGE = s__(
  'Workspaces|Could not load available agents. Refresh the page to try again.',
);

export default {
  components: {
    GlAlert,
    AgentsTable,
    GetAvailableAgentsQuery,
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
  methods: {
    onGetAvailableAgentsQueryResult({ agents }) {
      this.agents = agents;
    },
    onGetAvailableAgentsQueryError() {
      this.errorMessage = ERROR_LOADING_AVAILABLE_AGENTS_MESSAGE;
    },
  },
  NO_ALLOWED_AGENTS_MESSAGE,
};
</script>
<template>
  <div>
    <get-available-agents-query
      :namespace="namespace"
      @result="onGetAvailableAgentsQueryResult"
      @error="onGetAvailableAgentsQueryError"
    >
      <template #default="{ loading }">
        <gl-alert v-if="errorMessage" variant="danger" :dismissible="false">
          {{ errorMessage }}
        </gl-alert>
        <agents-table
          v-else
          :agents="agents"
          :is-loading="loading"
          :empty-state-message="$options.NO_ALLOWED_AGENTS_MESSAGE"
        />
      </template>
    </get-available-agents-query>
  </div>
</template>
