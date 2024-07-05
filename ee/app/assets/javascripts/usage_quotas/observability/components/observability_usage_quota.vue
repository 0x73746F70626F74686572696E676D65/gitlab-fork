<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import ObservabilityUsageBreakdown from './observability_usage_breakdown.vue';

export default {
  name: 'ObservabilityUsageQuotaApp',
  components: {
    GlLoadingIcon,
    ObservabilityUsageBreakdown,
  },
  props: {
    observabilityClient: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      usageData: null,
    };
  },
  created() {
    this.fetchUsageData();
  },
  methods: {
    async fetchUsageData() {
      this.loading = true;
      try {
        this.usageData = await this.observabilityClient.fetchUsageData();
      } catch (e) {
        createAlert({
          message: s__('Observability|Failed to load observability usage data.'),
        });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <section>
    <gl-loading-icon v-if="loading" size="lg" class="gl-mt-5" />

    <div v-else-if="usageData" class="gl-pt-5">
      <observability-usage-breakdown :usage-data="usageData" />
    </div>
  </section>
</template>
