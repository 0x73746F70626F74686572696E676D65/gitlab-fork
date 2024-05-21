<script>
import { GlEmptyState, GlLink, GlLoadingIcon, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { GlSingleStat, GlLineChart } from '@gitlab/ui/dist/charts';
import CHART_EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { formatDate } from '~/lib/utils/datetime_utility';

import {
  formatSeconds,
  runnerWaitTimeQueryData,
  runnerWaitTimeHistoryQueryData,
} from 'ee/ci/runner/runner_performance_utils';

export default {
  name: 'RunnerWaitTimes',
  components: {
    HelpPopover,
    GlEmptyState,
    GlLink,
    GlLoadingIcon,
    GlSkeletonLoader,
    GlSprintf,
    GlSingleStat,
    GlLineChart,
  },
  props: {
    waitTimes: {
      type: Object,
      required: false,
      default: null,
    },
    waitTimesLoading: {
      type: Boolean,
      required: false,
      default: false,
    },

    waitTimeHistoryEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    waitTimeHistory: {
      type: Array,
      required: false,
      default: () => [],
    },
    waitTimeHistoryLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    waitTimesStatsData() {
      return runnerWaitTimeQueryData(this.waitTimes);
    },
    waitTimeHistoryChartData() {
      return runnerWaitTimeHistoryQueryData(this.waitTimeHistory);
    },
  },
  methods: {
    formatSeconds(value) {
      return formatSeconds(value);
    },
  },
  jobDurationHelpPagePath: helpPagePath('ci/runners/runners_scope', {
    anchor: 'view-statistics-for-runner-performance',
  }),
  chartOption: {
    xAxis: {
      name: s__('Runners|UTC Time'),
      type: 'time',
      axisLabel: {
        formatter: (value) => formatDate(value, 'HH:MM', true),
      },
    },
    yAxis: {
      name: s__('Runners|Wait time (secs)'),
    },
  },
  CHART_EMPTY_STATE_SVG_URL,
};
</script>
<template>
  <div class="gl-border gl-rounded-base gl-p-5">
    <div class="gl-display-flex">
      <h2 class="gl-font-lg gl-mt-0">
        {{ s__('Runners|Wait time to pick a job') }}
        <help-popover trigger-class="gl-align-baseline">
          <gl-sprintf
            :message="
              s__(
                'Runners|The time it takes for an instance runner to pick up a job. Jobs waiting for runners are in the pending state. %{linkStart}How is this calculated?%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.jobDurationHelpPagePath">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </help-popover>
      </h2>
      <gl-loading-icon v-if="waitTimesLoading || waitTimeHistoryLoading" class="gl-ml-auto" />
    </div>

    <div class="gl-display-flex gl-flex-wrap gl-gap-3">
      <gl-single-stat
        v-for="stat in waitTimesStatsData"
        :key="stat.key"
        :title="stat.title"
        :value="stat.value"
        :unit="s__('Units|sec')"
      />
    </div>
    <div v-if="waitTimeHistoryEnabled">
      <div
        v-if="waitTimeHistoryLoading && !waitTimeHistoryChartData.length"
        class="gl-py-4 gl--flex-center"
      >
        <gl-skeleton-loader :equal-width-lines="true" />
      </div>
      <gl-empty-state
        v-else-if="!waitTimeHistoryChartData.length"
        :svg-path="$options.CHART_EMPTY_STATE_SVG_URL"
        :description="s__('Runners|No jobs have been run by instance runners in the past 3 hours.')"
      />
      <gl-line-chart
        v-else
        :include-legend-avg-max="false"
        :data="waitTimeHistoryChartData"
        :option="$options.chartOption"
      >
        <template #tooltip-value="{ value }">{{ formatSeconds(value) }}</template>
      </gl-line-chart>
    </div>
  </div>
</template>
