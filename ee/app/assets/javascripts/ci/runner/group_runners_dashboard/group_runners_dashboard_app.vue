<script>
import { GlButton } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { GROUP_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';
import RunnerListHeader from '~/ci/runner/components/runner_list_header.vue';
import RunnerUsage from '../components/runner_usage.vue';

import RunnerDashboardStatStatus from '../components/runner_dashboard_stat_status.vue';
import GroupRunnersActiveList from './group_runners_active_list.vue';
import GroupRunnersWaitTimes from './group_runners_wait_times.vue';

const trackingMixin = InternalEvents.mixin();

export default {
  components: {
    GlButton,
    GroupRunnersActiveList,
    GroupRunnersWaitTimes,
    RunnerListHeader,
    RunnerDashboardStatStatus,
    RunnerUsage,
  },
  mixins: [trackingMixin],
  inject: {
    clickhouseCiAnalyticsAvailable: {
      default: false,
    },
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
    },
    groupRunnersPath: {
      type: String,
      required: true,
    },
    newRunnerPath: {
      type: String,
      required: true,
    },
  },
  mounted() {
    this.trackEvent('view_runner_fleet_dashboard_pageload', {
      label: 'group',
    });
  },
  GROUP_TYPE,
  STATUS_ONLINE,
  STATUS_OFFLINE,
};
</script>
<template>
  <div>
    <runner-list-header>
      <template #title>{{ s__('Runners|Fleet dashboard') }}</template>
      <template #actions>
        <gl-button variant="link" :href="groupRunnersPath">{{
          s__('Runners|View runners list')
        }}</gl-button>
        <gl-button variant="confirm" :href="newRunnerPath">
          {{ s__('Runners|New group runner') }}
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
            :scope="$options.GROUP_TYPE"
            :status="$options.STATUS_ONLINE"
            :variables="{ groupFullPath: groupFullPath }"
            class="runners-dashboard-half-gap-4"
          />
          <runner-dashboard-stat-status
            :scope="$options.GROUP_TYPE"
            :status="$options.STATUS_OFFLINE"
            :variables="{ groupFullPath: groupFullPath }"
            class="runners-dashboard-half-gap-4"
          />
          <runner-usage
            v-if="clickhouseCiAnalyticsAvailable"
            :group-full-path="groupFullPath"
            :scope="$options.GROUP_TYPE"
            class="gl-flex-basis-full"
          />
        </div>
      </div>

      <group-runners-active-list
        :group-full-path="groupFullPath"
        class="runners-dashboard-third-gap-4 gl-mb-4"
      />
    </div>
    <group-runners-wait-times :group-full-path="groupFullPath" />
  </div>
</template>
