<script>
import { GlLabel, GlPopover } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { FRAMEWORKS_LABEL_BACKGROUND } from '../../constants';
import FrameworkBadge from './framework_badge.vue';

export default {
  name: 'ComplianceFrameworksInfo',
  FRAMEWORKS_LABEL_BACKGROUND,
  components: {
    GlLabel,
    GlPopover,
    FrameworkBadge,
  },
  props: {
    frameworks: {
      type: Array,
      required: true,
    },
    projectName: {
      type: String,
      required: true,
    },
    showEditSingleFramework: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    popoverTitle() {
      return sprintf(this.$options.i18n.title, {
        projectName: this.projectName,
      });
    },
    isMultipleFrameworksApplied() {
      return this.frameworks.length > 1;
    },
    isSingleFrameworkApplied() {
      return this.frameworks.length === 1;
    },
  },
  i18n: {
    multipleFrameworks: s__('ComplianceFrameworks|Multiple frameworks'),
    title: s__('ComplianceFrameworks|Compliance frameworks applied to %{projectName}'),
  },
};
</script>
<template>
  <div>
    <template v-if="isMultipleFrameworksApplied">
      <gl-popover
        ref="popover"
        :target="() => $refs.label"
        :title="popoverTitle"
        triggers="hover focus"
        placement="right"
      >
        <framework-badge
          v-for="framework in frameworks"
          :key="framework.id"
          :framework="framework"
          data-testid="framework-label"
          class="gl-mb-3 gl-mr-2 gl-display-inline-block"
          :show-popover="false"
        />
      </gl-popover>
      <span ref="label">
        <gl-label
          data-testid="frameworks-info-label"
          class="gl-mt-3 gl-cursor-pointer"
          :background-color="$options.FRAMEWORKS_LABEL_BACKGROUND"
          :title="$options.i18n.multipleFrameworks"
        />
      </span>
    </template>
    <framework-badge
      v-else-if="isSingleFrameworkApplied"
      class="gl-mt-3"
      data-testid="single-framework-label"
      :show-edit="showEditSingleFramework"
      :framework="frameworks[0]"
    />
  </div>
</template>
