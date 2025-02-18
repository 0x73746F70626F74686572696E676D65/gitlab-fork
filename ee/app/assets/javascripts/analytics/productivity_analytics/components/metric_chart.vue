<script>
import { GlCollapsibleListbox, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import { s__ } from '~/locale';

export default {
  name: 'MetricChart',
  components: {
    GlCollapsibleListbox,
    GlLoadingIcon,
    GlAlert,
  },
  props: {
    title: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    errorCode: {
      type: Number,
      required: false,
      default: null,
    },
    metricTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedMetric: {
      type: String,
      required: false,
      default: '',
    },
    chartData: {
      type: [Object, Array],
      required: false,
      default: () => [],
    },
  },
  computed: {
    hasMetricTypes() {
      return this.metricTypes.length;
    },
    metricDropdownLabel() {
      const foundMetric = this.metricTypes.find((m) => m.key === this.selectedMetric);
      return foundMetric ? foundMetric.label : s__('MetricChart|Please select a metric');
    },
    isServerError() {
      return this.errorCode === HTTP_STATUS_INTERNAL_SERVER_ERROR;
    },
    hasChartData() {
      return !isEmpty(this.chartData);
    },
    listBoxMetricTypes() {
      return this.metricTypes.map(({ key, label, ...props }) => ({
        value: key,
        text: label,
        ...props,
      }));
    },
    infoMessage() {
      if (this.isServerError) {
        return s__(
          'MetricChart|There is too much data to calculate. Please change your selection.',
        );
      }
      if (!this.hasChartData) {
        return s__('MetricChart|There is no data available. Please change your selection.');
      }

      return null;
    },
  },
};
</script>
<template>
  <div>
    <h5 v-if="title">{{ title }}</h5>
    <gl-loading-icon v-if="isLoading" size="lg" class="my-4 py-4" />
    <template v-else>
      <gl-alert v-if="infoMessage" :dismissible="false">{{ infoMessage }}</gl-alert>
      <template v-else>
        <gl-collapsible-listbox
          v-if="hasMetricTypes"
          class="gl-mb-4 metric-dropdown"
          fluid-width
          is-check-centered
          toggle-class="dropdown-menu-toggle !gl-w-full"
          :items="listBoxMetricTypes"
          :toggle-text="metricDropdownLabel"
          :selected="selectedMetric"
          @select="$emit('metricTypeChange', $event)"
        />

        <p v-if="description" class="text-muted">{{ description }}</p>
        <div ref="chart">
          <slot v-if="hasChartData"></slot>
        </div>
      </template>
    </template>
  </div>
</template>
