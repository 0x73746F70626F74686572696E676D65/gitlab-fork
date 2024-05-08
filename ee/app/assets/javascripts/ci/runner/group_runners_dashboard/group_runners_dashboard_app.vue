<script>
import { GlButton } from '@gitlab/ui';
import RunnerListHeader from '~/ci/runner/components/runner_list_header.vue';

import GroupRunnerActiveList from './group_runners_active_list.vue';

export default {
  components: {
    GlButton,
    GroupRunnerActiveList,
    RunnerListHeader,
  },
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

    <group-runner-active-list :group-full-path="groupFullPath" />
  </div>
</template>
