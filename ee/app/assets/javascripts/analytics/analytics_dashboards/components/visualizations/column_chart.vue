<script>
import { GlColumnChart } from '@gitlab/ui/dist/charts';
import merge from 'lodash/merge';

import { formatVisualizationTooltipTitle, formatVisualizationValue } from './utils';

export default {
  name: 'ColumnChart',
  components: {
    GlColumnChart,
  },
  props: {
    data: {
      type: Array,
      required: false,
      default: () => [],
    },
    options: {
      type: Object,
      required: true,
    },
  },
  computed: {
    fullOptions() {
      return merge({ yAxis: { min: 0 } }, this.options);
    },
  },
  methods: {
    formatVisualizationValue,
    formatVisualizationTooltipTitle,
  },
};
</script>

<template>
  <gl-column-chart
    :x-axis-type="fullOptions.xAxis.type"
    :x-axis-title="fullOptions.xAxis.name"
    :y-axis-title="fullOptions.yAxis.name"
    :bars="data"
    :option="fullOptions"
    height="auto"
    responsive
    data-testid="dashboard-visualization-column-chart"
    class="gl-overflow-hidden"
  >
    <template #tooltip-title="{ title, params }">
      {{ formatVisualizationTooltipTitle(title, params) }}</template
    >
    <template #tooltip-value="{ value }">{{ formatVisualizationValue(value) }}</template>
  </gl-column-chart>
</template>
