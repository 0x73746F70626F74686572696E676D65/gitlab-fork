<script>
import { GRANULARITIES } from '@cubejs-client/vue';
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';

import { s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

import {
  mapQueryToTokenValues,
  mapTimeDimensionQueryToValue,
  mapTokenValuesToQuery,
} from '../../../utils/visualization_designer_mappers';
import { getDimensionsForSchema, getMetricSchema, getTimeDimensionForSchema } from '../../../utils';
import {
  DEFAULT_VISUALIZATION_QUERY_STATE,
  MEASURE,
  DIMENSION,
  TIME_DIMENSION,
} from '../../../constants';

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
    availableTimeDimensions: {
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
    timeDimensionToken() {
      return {
        unique: true,
        title: s__('ProductAnalytics|Group by'),
        type: TIME_DIMENSION,
        operators: OPERATORS_IS,
        options: this.$options.GRANULARITIES.filter(({ title, name }) => title && name).map(
          ({ title, name }) => ({
            title,
            value: mapTimeDimensionQueryToValue({
              dimension: this.schemaTimeDimension?.name,
              granularity: name,
            }),
          }),
        ),
        token: GlFilteredSearchToken,
      };
    },
    availableTokens() {
      const tokens = [this.measureToken];
      if (this.schemaDimensions.length > 0) {
        tokens.push(this.dimensionToken);
      }
      if (this.schemaTimeDimension) {
        tokens.push(this.timeDimensionToken);
      }

      return tokens;
    },
    selectedSchema() {
      if (this.value.length < 1) return null;
      const measureToken = this.value.find((token) => token.type === MEASURE);

      if (!measureToken) return null;

      return getMetricSchema(measureToken.value.data);
    },
    schemaDimensions() {
      return getDimensionsForSchema(this.selectedSchema, this.availableDimensions);
    },
    schemaTimeDimension() {
      return getTimeDimensionForSchema(this.selectedSchema, this.availableTimeDimensions);
    },
  },
  watch: {
    query(query) {
      this.value = mapQueryToTokenValues(query, this.availableTokens);
    },
    value(value) {
      const measures = value.filter((token) => token.type === MEASURE);
      const dimensions = value.filter((token) => token.type === DIMENSION);
      const timeDimensions = value.filter((token) => token.type === TIME_DIMENSION);

      // Remove dangling dimensions/timeDimensions after dependent tokens removed
      if (measures.length < 1 && dimensions.length > 0) {
        this.value = this.value.filter((token) => token.type !== DIMENSION);
      }
      if (measures.length < 1 && timeDimensions.length > 0) {
        this.value = this.value.filter((token) => token.type !== TIME_DIMENSION);
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
  GRANULARITIES,
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
