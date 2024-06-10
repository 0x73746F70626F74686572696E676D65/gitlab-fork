<script>
import { GlButton } from '@gitlab/ui';
import { INSTANCE_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';
import RunnerListHeader from '~/ci/runner/components/runner_list_header.vue';

import RunnerDashboardStatStatus from '../components/runner_dashboard_stat_status.vue';
import RunnerUsage from '../components/runner_usage.vue';
import RunnerJobFailures from '../components/runner_job_failures.vue';

import AdminRunnersActiveList from './admin_runners_active_list.vue';
import AdminRunnersWaitTimes from './admin_runners_wait_times.vue';

export default {
  components: {
    GlButton,
    AdminRunnersActiveList,
    AdminRunnersWaitTimes,
    RunnerListHeader,
    RunnerDashboardStatStatus,
    RunnerUsage,
    RunnerJobFailures,
  },
  inject: {
    clickhouseCiAnalyticsAvailable: {
      default: false,
    },
  },
  props: {
    adminRunnersPath: {
      type: String,
      required: true,
    },
    newRunnerPath: {
      type: String,
      required: true,
    },
  },
  INSTANCE_TYPE,
  STATUS_ONLINE,
  STATUS_OFFLINE,
};
</script>
<template>
  <div>
    <runner-list-header>
      <template #title>{{ s__('Runners|Fleet dashboard') }}</template>
      <template #actions>
        <gl-button variant="link" :href="adminRunnersPath">{{
          s__('Runners|View runners list')
        }}</gl-button>
        <gl-button variant="confirm" :href="newRunnerPath">
          {{ s__('Runners|New instance runner') }}
        </gl-button>
      </template>
    </runner-list-header>

    <p>
      {{ s__('Runners|Use the dashboard to view performance statistics of your runner fleet.') }}
    </p>

    <div class="sm:gl-flex gl-gap-x-4 gl-justify-between">
      <div class="sm:gl-flex gl-gap-x-4 gl-justify-between gl-w-full">
        <div
          class="runners-dashboard-two-thirds-gap-4 gl-display-flex gl-gap-4 gl-justify-between gl-mb-4 gl-flex-wrap"
        >
          <runner-dashboard-stat-status
            :status="$options.STATUS_ONLINE"
            :scope="$options.INSTANCE_TYPE"
            class="runners-dashboard-half-gap-4"
          />
          <runner-dashboard-stat-status
            :status="$options.STATUS_OFFLINE"
            :scope="$options.INSTANCE_TYPE"
            class="runners-dashboard-half-gap-4"
          />

          <!-- we use job failures as fallback, when clickhouse is not available -->
          <runner-usage
            v-if="clickhouseCiAnalyticsAvailable"
            :scope="$options.INSTANCE_TYPE"
            class="gl-flex-basis-full"
          />
          <runner-job-failures v-else class="gl-flex-basis-full" />
        </div>

        <admin-runners-active-list class="runners-dashboard-third-gap-4 gl-mb-4" />
      </div>
    </div>
    <admin-runners-wait-times class="gl-mb-4" />
  </div>
</template>
