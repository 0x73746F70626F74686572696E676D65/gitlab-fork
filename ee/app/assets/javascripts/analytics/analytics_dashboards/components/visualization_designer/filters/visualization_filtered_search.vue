<script>
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';
import { s__ } from '~/locale';

import {
  mapQueryToTokenValues,
  mapTokenValuesToQuery,
} from 'ee/analytics/analytics_dashboards/utils/visualization_designer_mappers';
import {
  DEFAULT_VISUALIZATION_QUERY_STATE,
  MEASURE,
  DIMENSION,
} from 'ee/analytics/analytics_dashboards/constants';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export default {
  name: 'VisualizationFilteredSearch',
  components: {
    GlFilteredSearch,
  },
  props: {
    query: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    availableMeasures: {
      type: Array,
      required: true,
    },
    availableDimensions: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      value: mapQueryToTokenValues(this.query),
    };
  },
  computed: {
    measureToken() {
      return {
        unique: true,
        title: s__('ProductAnalytics|Measure'),
        type: MEASURE,
        operators: OPERATORS_IS,
        options: this.getTokenOptions(this.availableMeasures),
        token: GlFilteredSearchToken,
      };
    },
    dimensionToken() {
      return {
        title: s__('ProductAnalytics|Dimension'),
        type: DIMENSION,
        operators: OPERATORS_IS,
        options: this.getTokenOptions(this.schemaDimensions),
        token: GlFilteredSearchToken,
      };
    },
    availableTokens() {
      if (this.schemaDimensions.length > 0) {
        return [this.measureToken, this.dimensionToken];
      }

      return [this.measureToken];
    },
    schemaDimensions() {
      if (this.value.length < 1) return [];

      const measureToken = this.value.find((token) => token.type === MEASURE);

      if (!measureToken) return [];

      const selectedSchema = this.getMetricSchema(measureToken.value.data);

      return this.availableDimensions.filter(
        ({ name }) => this.getMetricSchema(name) === selectedSchema,
      );
    },
  },
  watch: {
    query(query) {
      this.value = mapQueryToTokenValues(query);
    },
    value(value) {
      const measures = value.filter((token) => token.type === MEASURE);
      const dimensions = value.filter((token) => token.type === DIMENSION);

      // Remove dangling dimensions after the measure was removed
      if (measures.length < 1 && dimensions.length > 0) {
        this.value = this.value.filter((token) => token.type !== DIMENSION);
      }
    },
  },
  methods: {
    getTokenOptions(cubeMetrics) {
      return cubeMetrics
        .filter((metric) => metric.isVisible)
        .map((metric) => ({
          title: metric.title,
          value: metric.name,
        }));
    },
    getMetricSchema(metric) {
      return metric.split('.')[0];
    },
    onSubmit(value) {
      this.$emit('submit', {
        ...DEFAULT_VISUALIZATION_QUERY_STATE().query,
        ...mapTokenValuesToQuery(value, this.availableTokens),
      });
    },
    onInput(value) {
      this.$emit('input', {
        ...DEFAULT_VISUALIZATION_QUERY_STATE().query,
        ...mapTokenValuesToQuery(value, this.availableTokens),
      });
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-py-5 gl-border-b">
    <gl-filtered-search
      :value="value"
      :available-tokens="availableTokens"
      :placeholder="s__('Analytics|Start by choosing a measure')"
      :clear-button-title="__('Clear')"
      terms-as-tokens
      @submit="onSubmit"
      @input="onInput"
    />
  </div>
</template>
