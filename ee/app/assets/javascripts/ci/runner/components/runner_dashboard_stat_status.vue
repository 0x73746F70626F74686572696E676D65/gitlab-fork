<script>
import { GlIcon } from '@gitlab/ui';
import {
  INSTANCE_TYPE,
  GROUP_TYPE,
  I18N_STATUS_ONLINE,
  I18N_STATUS_OFFLINE,
  STATUS_ONLINE,
  STATUS_OFFLINE,
} from '~/ci/runner/constants';
import RunnerDashboardStat from './runner_dashboard_stat.vue';

export default {
  name: 'RunnerDashboardStatStatus',
  components: {
    GlIcon,
    RunnerDashboardStat,
  },
  props: {
    scope: {
      type: String,
      required: true,
      validator: (val) => [INSTANCE_TYPE, GROUP_TYPE].includes(val),
    },
    status: {
      type: String,
      required: true,
      validator: (val) => [STATUS_ONLINE, STATUS_OFFLINE].includes(val),
    },
    variables: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    title() {
      switch (this.status) {
        case STATUS_ONLINE:
          return I18N_STATUS_ONLINE;
        case STATUS_OFFLINE:
          return I18N_STATUS_OFFLINE;
        default:
          return null;
      }
    },
    icon() {
      switch (this.status) {
        case STATUS_ONLINE:
          return { class: 'gl-text-green-500', name: 'status-active' };
        case STATUS_OFFLINE:
          return { class: 'gl-text-gray-500', name: 'status-waiting' };
        default:
          return null;
      }
    },
  },
};
</script>

<template>
  <runner-dashboard-stat :scope="scope" :variables="{ ...variables, status }">
    <template #title>
      <gl-icon v-if="icon" :class="icon.class" :size="12" :name="icon.name" />
      {{ title }}
    </template>
  </runner-dashboard-stat>
</template>
