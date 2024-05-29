<script>
import { GlSkeletonLoader, GlTable, GlCard } from '@gitlab/ui';
import { __ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';

const AGENT_MAPPING_STATUS_LABELS = {
  [AGENT_MAPPING_STATUS_MAPPED]: __('Allowed'),
  [AGENT_MAPPING_STATUS_UNMAPPED]: __('Blocked'),
};

const NAME_FIELD = {
  key: 'name',
  label: __('Name'),
  sortable: true,
};

const MAPPING_STATUS_LABEL_FIELD = {
  key: 'mappingStatusLabel',
  label: __('Availability'),
  sortable: true,
};

export default {
  components: {
    GlSkeletonLoader,
    GlTable,
    GlCard,
  },
  directives: {
    SafeHtml,
  },
  props: {
    agents: {
      type: Array,
      required: true,
    },
    namespaceId: {
      type: String,
      required: false,
      default: '',
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
        mappingStatusLabel: AGENT_MAPPING_STATUS_LABELS[agent.mappingStatus],
      }));
    },
    fields() {
      const fields = [NAME_FIELD];

      if (this.displayMappingStatus) {
        fields.push(MAPPING_STATUS_LABEL_FIELD);
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
        <span data-testid="agent-mapping-status-label">{{ item.mappingStatusLabel }}</span>
      </template>
    </gl-table>
  </gl-card>
</template>
