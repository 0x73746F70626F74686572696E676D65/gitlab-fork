<script>
import ObservabilityContainer from '~/observability/components/observability_container.vue';
import TracingDetails from './details/tracing_details.vue';

export default {
  components: {
    ObservabilityContainer,
    TracingDetails,
  },
  props: {
    traceId: {
      type: String,
      required: true,
    },
    tracingIndexUrl: {
      required: true,
      type: String,
    },
    logsIndexUrl: {
      required: true,
      type: String,
    },
    apiConfig: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <observability-container :api-config="apiConfig">
    <template #default="{ observabilityClient }">
      <tracing-details
        :trace-id="traceId"
        :tracing-index-url="tracingIndexUrl"
        :logs-index-url="logsIndexUrl"
        :observability-client="observabilityClient"
      />
    </template>
  </observability-container>
</template>
