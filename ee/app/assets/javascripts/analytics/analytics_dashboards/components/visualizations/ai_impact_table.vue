<script>
import { GlLoadingIcon } from '@gitlab/ui';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';

export default {
  name: 'AiImpactTable',
  components: {
    GlLoadingIcon,
    GroupOrProjectProvider,
    MetricTable,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <group-or-project-provider
    #default="{ isProject, isNamespaceLoading }"
    :full-path="data.namespace"
  >
    <div v-if="isNamespaceLoading" class="gl-flex gl-justify-center gl-items-center gl-h-full">
      <gl-loading-icon size="lg" />
    </div>
    <metric-table
      v-else
      :namespace="data.namespace"
      :is-project="isProject"
      @set-alerts="$emit('set-alerts', $event)"
    />
  </group-or-project-provider>
</template>
