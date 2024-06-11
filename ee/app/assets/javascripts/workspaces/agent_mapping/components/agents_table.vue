<script>
import { GlSkeletonLoader, GlBadge, GlTable, GlCard } from '@gitlab/ui';
import { __ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';
import AgentMappingStatusToggle from './agent_mapping_status_toggle.vue';
import ToggleAgentMappingStatusMutation from './toggle_agent_mapping_status_mutation.vue';

const AGENT_MAPPING_STATUS_BADGES = {
  [AGENT_MAPPING_STATUS_MAPPED]: {
    text: __('Allowed'),
    variant: 'success',
  },
  [AGENT_MAPPING_STATUS_UNMAPPED]: {
    text: __('Blocked'),
    variant: 'danger',
  },
};

const NAME_FIELD = {
  key: 'name',
  label: __('Name'),
  sortable: true,
  thClass: 'gl-w-3/4',
};

const MAPPING_STATUS_LABEL_FIELD = {
  key: 'mappingStatusLabel',
  label: __('Availability'),
  sortable: true,
  thClass: 'gl-w-3/20',
};

const MAPPING_ACTIONS_FIELD = {
  key: 'actions',
  label: __('Action'),
  sortable: false,
  thClass: 'gl-w-3/10',
};

export default {
  components: {
    GlBadge,
    GlCard,
    GlSkeletonLoader,
    GlTable,
    AgentMappingStatusToggle,
    ToggleAgentMappingStatusMutation,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    canAdminClusterAgentMapping: {
      default: false,
    },
  },
  props: {
    agents: {
      type: Array,
      required: true,
    },
    namespaceId: {
      type: String,
      required: true,
    },
    emptyStateMessage: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    displayMappingStatus: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    agentsWithStatusLabels() {
      return this.agents.map((agent) => ({
        ...agent,
        statusBadge: {
          ...AGENT_MAPPING_STATUS_BADGES[agent.mappingStatus],
        },
      }));
    },
    fields() {
      const fields = [NAME_FIELD];

      if (this.displayMappingStatus) {
        fields.push(MAPPING_STATUS_LABEL_FIELD);
      }

      if (this.canAdminClusterAgentMapping) {
        fields.push(MAPPING_ACTIONS_FIELD);
      }

      return fields;
    },
  },
};
</script>
<template>
  <gl-card body-class="gl-new-card-body">
    <div v-if="isLoading" class="p-3 flex justify-start">
      <gl-skeleton-loader :lines="4" :equal-width-lines="true" :width="600" />
    </div>
    <gl-table v-else :fields="fields" :items="agentsWithStatusLabels" show-empty stacked="sm">
      <template #empty>
        <div v-safe-html="emptyStateMessage" class="text-center"></div>
      </template>
      <template #cell(name)="{ item }">
        <span data-testid="agent-name">{{ item.name }}</span>
      </template>
      <template v-if="displayMappingStatus" #cell(mappingStatusLabel)="{ item }">
        <gl-badge :variant="item.statusBadge.variant" data-testid="agent-mapping-status-label">{{
          item.statusBadge.text
        }}</gl-badge>
      </template>
      <template v-if="canAdminClusterAgentMapping" #cell(actions)="{ item }">
        <toggle-agent-mapping-status-mutation :namespace-id="namespaceId" :agent="item">
          <template #default="{ execute, loading }">
            <agent-mapping-status-toggle :agent="item" :loading="loading" @toggle="execute" />
          </template>
        </toggle-agent-mapping-status-mutation>
      </template>
    </gl-table>
  </gl-card>
</template>
