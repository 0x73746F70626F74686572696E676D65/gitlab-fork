<script>
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';
import LogsList from './list/logs_list.vue';

export default {
  components: {
    ProvisionedObservabilityContainer,
    LogsList,
  },
  props: {
    apiConfig: {
      type: Object,
      required: true,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <provisioned-observability-container :api-config="apiConfig">
    <template #default="{ observabilityClient }">
      <logs-list :observability-client="observabilityClient" :tracing-index-url="tracingIndexUrl" />
    </template>
  </provisioned-observability-container>
</template>
