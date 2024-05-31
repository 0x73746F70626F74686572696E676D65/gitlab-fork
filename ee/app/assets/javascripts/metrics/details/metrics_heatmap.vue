<script>
import { GlHeatmap } from '@gitlab/ui/dist/charts';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime_utility';

export default {
  components: {
    GlHeatmap,
  },
  i18n: {
    cancelledText: s__('ObservabilityMetrics|Metrics search has been cancelled.'),
  },
  props: {
    metricData: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    cancelled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    heatmapData() {
      // There might be multiple distributions, but for now we only render the first one
      return (
        this.metricData[0]?.data?.[0] || {
          distribution: [],
          buckets: [],
        }
      );
    },
    chartData() {
      return this.heatmapData.distribution.flatMap((arr, bucketIndex) =>
        arr.map((entry, timeIndex) => [
          timeIndex,
          bucketIndex,
          parseFloat(entry[1]), // value
        ]),
      );
    },

    xAxisLabels() {
      /**
       * A distribution is represented as a bi-dimensional array, e.g. 
       * { distribution: [
            //bucket 0
            [
              [ts_1, v_a],
              [ts_2, v_b],
              [ts_3, v_c],
            ],
            //bucket 1
            [
              [ts_1, v_d],
              [ts_2, v_e],
              [ts_3, v_f],
            ],
            ... ]}
       * */

      const distribution = this.heatmapData.distribution[0] || [];
      // timestamps are in nano, we need to convert them to ms
      const timeIntervals = distribution.map((entry) => entry[0] / 1e6);
      return timeIntervals.map((entry) => formatDate(entry, 'HH:MM'));
    },
    yAxisLabels() {
      return this.heatmapData.buckets;
    },
    chartOptions() {
      return {
        tooltip: {
          // show the default tooltip
        },
        xAxis: {
          axisPointer: {
            show: false,
          },
        },
      };
    },
  },
};
</script>

<template>
  <div class="gl-relative">
    <gl-heatmap
      :class="{ 'gl-opacity-3': loading || cancelled }"
      :x-axis-labels="xAxisLabels"
      :y-axis-labels="yAxisLabels"
      :data-series="chartData"
      :options="chartOptions"
      :show-tooltip="false"
      responsive
    />
    <div
      v-if="cancelled"
      class="gl-absolute gl-right-0 gl-left-0 gl-top-0 gl-bottom-0 gl-text-center gl-font-bold gl-font-lg gl-py-2"
    >
      <span>{{ $options.i18n.cancelledText }}</span>
    </div>
  </div>
</template>
