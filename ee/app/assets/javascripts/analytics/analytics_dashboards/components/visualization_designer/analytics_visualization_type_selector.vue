<script>
import { GlFormSelect } from '@gitlab/ui';
import { s__ } from '~/locale';

const TYPES = [
  {
    value: '',
    disabled: true,
    text: s__('Analytics|Select a visualization type'),
  },
  {
    value: 'LineChart',
    text: s__('Analytics|Line chart'),
  },
  {
    value: 'ColumnChart',
    text: s__('Analytics|Column chart'),
  },
  {
    value: 'DataTable',
    text: s__('Analytics|Data table'),
  },
  {
    value: 'SingleStat',
    text: s__('Analytics|Single statistic'),
  },
];

export default {
  name: 'AnalyticsVisualizationTypeSelector',
  components: {
    GlFormSelect,
  },
  props: {
    state: {
      type: Boolean,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: true,
    },
  },
  TYPES,
};
</script>

<template>
  <gl-form-select
    :value="value"
    :state="state"
    :options="$options.TYPES"
    @input="$emit('input', $event)"
  />
</template>
