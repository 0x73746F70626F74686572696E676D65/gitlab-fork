<script>
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';
import ObservabilityUsageQuota from './observability_usage_quota.vue';

export default {
  name: 'ObservabilityUsageQuotaApp',
  components: {
    ObservabilityUsageQuota,
    ProvisionedObservabilityContainer,
  },
  inject: {
    apiConfig: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <section>
    <provisioned-observability-container :api-config="apiConfig">
      <template #default="{ observabilityClient }">
        <observability-usage-quota :observability-client="observabilityClient" />
      </template>
    </provisioned-observability-container>
  </section>
</template>
