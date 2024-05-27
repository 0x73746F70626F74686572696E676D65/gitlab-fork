<script>
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime_utility';

export default {
  components: {
    GlLineChart,
    GlChartSeriesLabel,
  },
  i18n: {
    xAxisTitle: s__('ObservabilityMetrics|Date'),
    yAxisTitle: s__('ObservabilityMetrics|Value'),
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
  data() {
    return {
      tooltipTitle: '',
      tooltipContent: [],
    };
  },
  computed: {
    chartData() {
      return this.metricData.map((metric) => {
        const data = metric.values.map((value) => [
          // note date timestamps are in nano, so converting them to ms here
          value[0] / 1e6,
          parseFloat(value[1]),
          { ...metric.attributes },
        ]);
        return {
          name: Object.entries(metric.attributes)
            .map(([k, v]) => `${k}: ${v}`)
            .join(', '),
          data,
        };
      });
    },
    chartOption() {
      const yUnit = this.metricData?.[0]?.unit;
      const yAxisTitle = this.$options.i18n.yAxisTitle + (yUnit ? ` (${yUnit})` : '');
      return {
        dataZoom: [
          {
            type: 'slider',
          },
        ],
        xAxis: {
          type: 'time',
          name: this.$options.i18n.xAxisTitle,
        },
        yAxis: {
          name: yAxisTitle,
        },
      };
    },
  },
  methods: {
    formatTooltipText({ seriesData }) {
      // reset the tooltip
      this.tooltipTitle = '';
      this.tooltipContent = [];

      if (!Array.isArray(seriesData) || seriesData.length === 0) return;

      if (Array.isArray(seriesData[0].data)) {
        const [dateTime] = seriesData[0].data;
        this.tooltipTitle = formatDate(dateTime, 'mmm d, yyyy H:MM:ss');
      }

      this.tooltipContent = seriesData.map(({ seriesName, color, seriesId, data }) => {
        const [, metric, attr] = data;
        return {
          seriesId,
          label: seriesName,
          attributes: Object.entries(attr).map(([k, v]) => ({ key: k, value: v })),
          value: parseFloat(metric).toFixed(3),
          color,
        };
      });
    },
  },
};
</script>

<template>
  <div class="gl-relative">
    <gl-line-chart
      disabled
      :class="['gl-mb-7', { 'gl-opacity-3': loading || cancelled }]"
      :option="chartOption"
      :data="chartData"
      responsive
      :format-tooltip-text="formatTooltipText"
    >
      <template #tooltip-title>
        <div data-testid="metric-tooltip-title">{{ tooltipTitle }}</div>
      </template>

      <template #tooltip-content>
        <div
          v-for="(metric, index) in tooltipContent"
          :key="`${metric.seriesId}_${index}`"
          data-testid="metric-tooltip-content"
          class="gl-display-flex gl-justify-content-space-between gl-font-sm gl-mb-1"
        >
          <gl-chart-series-label :color="metric.color" class="gl-leading-normal gl-mr-7">
            <div v-for="attr in metric.attributes" :key="attr.key + attr.value">
              <span class="gl-font-weight-bold">{{ attr.key }}: </span>{{ attr.value }}
            </div>
          </gl-chart-series-label>

          <div data-testid="metric-tooltip-value" class="gl-font-weight-bold">
            {{ metric.value }}
          </div>
        </div>
      </template>
    </gl-line-chart>

    <div
      v-if="cancelled"
      class="gl-absolute gl-right-0 gl-left-0 gl-top-0 gl-bottom-0 gl-text-center gl-font-weight-bold gl-font-lg gl-py-13"
    >
      <span>{{ $options.i18n.cancelledText }}</span>
    </div>
  </div>
</template>

<style>
.chart-cancelled-text {
  padding-top: 30%;
}
</style>
