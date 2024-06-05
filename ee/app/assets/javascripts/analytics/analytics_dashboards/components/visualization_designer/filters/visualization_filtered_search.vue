<script>
import { GlFilteredSearch, GlFilteredSearchToken } from '@gitlab/ui';

import { s__ } from '~/locale';

import {
  mapQueryToTokenValues,
  mapTokenValuesToQuery,
} from 'ee/analytics/analytics_dashboards/utils/visualization_designer_mappers';
import { DEFAULT_VISUALIZATION_QUERY_STATE } from 'ee/analytics/analytics_dashboards/constants';

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
  },
  data() {
    return {
      value: mapQueryToTokenValues(this.query),
    };
  },
  computed: {
    availableTokens() {
      return [
        {
          unique: true,
          title: s__('ProductAnalytics|Measure'),
          type: 'measure',
          operators: [{ value: '=', description: 'is' }],
          options: this.availableMeasures
            .filter((measure) => measure.isVisible)
            .map((measure) => ({
              title: measure.title,
              value: measure.name,
            })),
          token: GlFilteredSearchToken,
        },
      ];
    },
  },
  watch: {
    query(query) {
      this.value = mapQueryToTokenValues(query);
    },
  },
  methods: {
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
