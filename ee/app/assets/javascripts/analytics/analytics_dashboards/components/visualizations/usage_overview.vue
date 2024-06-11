<script>
import { compact } from 'lodash';
import { GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __, sprintf } from '~/locale';
import dateFormat, { masks } from '~/lib/dateformat';
import SingleStat from './single_stat.vue';

export default {
  name: 'UsageOverview',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlIcon,
    SingleStat,
  },
  inject: {
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    recordedAt() {
      const allRecordedAt = compact(this.data.metrics.map((metric) => metric.recordedAt));
      const [mostRecentRecordedAt] = allRecordedAt.sort().slice(-1);

      if (!mostRecentRecordedAt) return null;

      return dateFormat(mostRecentRecordedAt, `${masks.isoDate} ${masks.shortTime}`);
    },
    avatarAltText() {
      const { fullName } = this.data.namespace;
      return sprintf(__("%{name}'s avatar"), { name: fullName });
    },
  },
  mounted() {
    const { recordedAt } = this;
    const { tooltip, lastUpdated } = this.$options.i18n;
    const text = `${tooltip}${recordedAt ? sprintf(lastUpdated, { recordedAt }) : ''}`;
    this.$emit('showTooltip', text);

    if (!this.overviewCountsAggregationEnabled) {
      const { description, descriptionLink, backgroundAggregationNoData } = this.$options.i18n;
      this.$emit('set-alerts', {
        title: this.$options.i18n.backgroundAggregationWarningTitle,
        description: backgroundAggregationNoData,
        warnings: [{ description, link: descriptionLink }],
        canRetry: false,
      });
    }
  },
  methods: {
    displayValue(value) {
      if (value > 0) return value;
      return this.overviewCountsAggregationEnabled ? 0 : '-';
    },
  },
  i18n: {
    tooltip: s__(
      'Analytics|Statistics on namespace usage. Usage data is a cumulative count, and updated monthly.',
    ),
    lastUpdated: s__('Analytics| Last updated: %{recordedAt}'),
    backgroundAggregationWarningTitle: s__('DORA4Metrics|Background aggregation not enabled'),
    description: s__(
      'DORA4Metrics|To see usage overview, you must %{linkStart}enable background aggregation%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/analytics/value_streams_dashboard.html', {
      anchor: 'enable-or-disable-overview-background-aggregation',
    }),
    backgroundAggregationNoData: __('No data available'),
  },
};
</script>
<template>
  <div class="gl-display-flex gl-md-flex-direction-column gl-flex-direction-row gl-font-size-sm">
    <div
      v-if="data.namespace"
      data-testid="usage-overview-namespace"
      class="gl-display-flex gl-align-items-center gl-gap-3 gl-pr-9"
    >
      <gl-avatar
        shape="rect"
        :src="data.namespace.avatarUrl"
        :size="48"
        :entity-name="data.namespace.fullName"
        :entity-id="data.namespace.id"
        :fallback-on-error="true"
        :alt="avatarAltText"
      />

      <div class="gl-leading-20">
        <span class="gl-block gl-mb-1 gl-font-base gl-font-normal gl-text-gray-700">{{
          data.namespace.namespaceType
        }}</span>
        <div class="gl-display-flex gl-align-items-center gl-gap-2">
          <span class="gl-font-size-h2 gl-font-bold gl-text-gray-900 gl-truncate-end">{{
            data.namespace.fullName
          }}</span>
          <gl-icon
            v-gl-tooltip.viewport
            class="gl-text-secondary"
            :name="data.namespace.visibilityLevelIcon"
            :title="data.namespace.visibilityLevelTooltip"
          />
        </div>
      </div>
    </div>

    <div
      v-for="metric in data.metrics"
      :key="metric.identifier"
      class="gl-pr-9"
      :data-testid="`usage-overview-metric-${metric.identifier}`"
    >
      <single-stat :data="displayValue(metric.value)" :options="metric.options" />
    </div>
  </div>
</template>
