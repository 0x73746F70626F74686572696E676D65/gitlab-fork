<script>
import { GlButton } from '@gitlab/ui';

export default {
  components: {
    GlButton,
  },
  inject: {
    runnerDashboardPath: {
      default: null,
    },
  },
};
</script>
<template>
  <gl-button v-if="runnerDashboardPath" variant="link" :href="runnerDashboardPath">
    {{ s__('Runners|Fleet dashboard') }}
  </gl-button>
</template>
