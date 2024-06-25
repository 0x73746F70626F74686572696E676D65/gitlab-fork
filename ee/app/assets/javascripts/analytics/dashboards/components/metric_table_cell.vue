<script>
import { GlIcon, GlLink, GlPopover } from '@gitlab/ui';
import { joinPaths, mergeUrlParams } from '~/lib/utils/url_utility';
import { METRIC_TOOLTIPS } from '~/analytics/shared/constants';
import { s__ } from '~/locale';
import { TABLE_METRICS } from '../constants';
import { AI_IMPACT_TABLE_METRICS } from '../ai_impact/constants';

export default {
  name: 'MetricTableCell',
  components: {
    GlIcon,
    GlLink,
    GlPopover,
  },
  props: {
    identifier: {
      type: String,
      required: true,
    },
    requestPath: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: true,
    },
    filterLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    metric() {
      return TABLE_METRICS[this.identifier] || AI_IMPACT_TABLE_METRICS[this.identifier];
    },
    tooltip() {
      return METRIC_TOOLTIPS[this.identifier];
    },
    link() {
      const { groupLink, projectLink } = this.tooltip;
      const url = joinPaths(
        '/',
        gon.relative_url_root,
        !this.isProject ? 'groups' : '',
        this.requestPath,
        this.isProject ? projectLink : groupLink,
      );

      if (!this.filterLabels.length) return url;

      return mergeUrlParams({ label_name: this.filterLabels }, url, { spreadArrays: true });
    },
    popoverTarget() {
      return `${this.requestPath}__${this.identifier}`.replace('/', '_');
    },
    hasRequestPath() {
      return Boolean(this.requestPath.length);
    },
  },
  i18n: {
    docsLabel: s__('DORA4Metrics|Go to docs'),
  },
};
</script>
<template>
  <div>
    <gl-link
      v-if="hasRequestPath"
      :href="link"
      data-testid="metric_label"
      @click="$emit('drill-down-clicked', $event)"
      >{{ metric.label }}</gl-link
    >
    <span v-else data-testid="metric_label">{{ metric.label }}</span>
    <gl-icon
      :id="popoverTarget"
      data-testid="info_icon"
      name="information-o"
      class="gl-text-blue-600"
    />
    <gl-popover :target="popoverTarget" :title="metric.label" show-close-button>
      {{ tooltip.description }}
      <gl-link :href="tooltip.docsLink" class="gl-block gl-mt-2 gl-font-sm" target="_blank">
        {{ $options.i18n.docsLabel }}
        <gl-icon name="external-link" class="gl-align-middle" />
      </gl-link>
    </gl-popover>
  </div>
</template>
