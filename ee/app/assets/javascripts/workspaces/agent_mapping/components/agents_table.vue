<script>
import { GlSkeletonLoader, GlTable, GlCard } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: {
    GlSkeletonLoader,
    GlTable,
    GlCard,
  },
  props: {
    agents: {
      type: Array,
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
  },
  fields: [
    {
      key: 'name',
      label: __('Name'),
      sortable: true,
    },
  ],
};
</script>
<template>
  <gl-card body-class="gl-new-card-body">
    <div v-if="isLoading" class="p-3 flex justify-start">
      <gl-skeleton-loader :lines="4" :equal-width-lines="true" :width="600" />
    </div>
    <gl-table v-else :fields="$options.fields" :items="agents" show-empty stacked="sm">
      <template #empty>
        <div class="text-center">{{ emptyStateMessage }}</div>
      </template>
      <template #cell(name)="{ item }">
        <span data-testid="agent-name">{{ item.name }}</span>
      </template>
    </gl-table>
  </gl-card>
</template>
