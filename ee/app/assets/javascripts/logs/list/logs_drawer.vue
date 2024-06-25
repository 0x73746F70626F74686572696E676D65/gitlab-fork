<script>
import { GlDrawer, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';

const createSectionContent = (obj) =>
  Object.entries(obj)
    .map(([k, v]) => ({ name: k, value: v }))
    .filter((e) => e.value)
    .sort((a, b) => (a.name > b.name ? 1 : -1));

export default {
  components: {
    GlDrawer,
    GlLink,
  },
  i18n: {
    logDetailsTitle: s__('ObservabilityLogs|Metadata'),
    logAttributesTitle: s__('ObservabilityLogs|Attributes'),
    resourceAttributesTitle: s__('ObservabilityLogs|Resource attributes'),
  },
  props: {
    log: {
      required: false,
      type: Object,
      default: null,
    },
    open: {
      required: true,
      type: Boolean,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
  computed: {
    sections() {
      if (this.log) {
        const {
          log_attributes: logAttributes,
          resource_attributes: resourceAttributes,
          ...rest
        } = this.log;

        const sections = [
          {
            content: createSectionContent(rest),
            title: this.$options.i18n.logDetailsTitle,
            key: 'log-details',
          },
        ];
        if (logAttributes) {
          sections.push({
            title: this.$options.i18n.logAttributesTitle,
            content: createSectionContent(logAttributes),
            key: 'log-attributes',
          });
        }
        if (resourceAttributes) {
          sections.push({
            title: this.$options.i18n.resourceAttributesTitle,
            content: createSectionContent(resourceAttributes),
            key: 'resource-attributes',
          });
        }
        return sections.filter(({ content }) => content.length);
      }
      return [];
    },
    title() {
      if (!this.log) return '';
      return formatDate(this.log.timestamp, 'isoUtcDateTime');
    },
    drawerHeaderHeight() {
      // avoid calculating this in advance because it causes layout thrashing
      // https://gitlab.com/gitlab-org/gitlab/-/issues/331172#note_1269378396
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
  },
  methods: {
    isTraceId(key) {
      return key === 'trace_id';
    },
    traceIdLink(traceId) {
      return `${this.tracingIndexUrl}/${traceId}`;
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="open"
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="drawerHeaderHeight"
    header-sticky
    @close="$emit('close')"
  >
    <template #title>
      <div data-testid="drawer-title">
        <h2 class="gl-font-size-h2 gl-my-0">{{ title }}</h2>
      </div>
    </template>

    <template #default>
      <div
        v-for="section in sections"
        :key="section.key"
        :data-testid="`section-${section.key}`"
        class="gl-border-none"
      >
        <h2 v-if="section.title" data-testid="section-title" class="gl-font-size-h2 gl-my-0">
          {{ section.title }}
        </h2>
        <div
          v-for="line in section.content"
          :key="line.name"
          data-testid="section-line"
          class="gl-py-5 gl-border-b-1 gl-border-b-solid gl-border-b-gray-200"
        >
          <label data-testid="section-line-name">{{ line.name }}</label>
          <div data-testid="section-line-value" class="gl-wrap-anywhere">
            <gl-link v-if="isTraceId(line.name)" :href="traceIdLink(line.value)">
              {{ line.value }}
            </gl-link>
            <template v-else>
              {{ line.value }}
            </template>
          </div>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
