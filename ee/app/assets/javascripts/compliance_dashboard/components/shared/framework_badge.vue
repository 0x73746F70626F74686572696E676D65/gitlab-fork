<script>
import { GlButton, GlLabel, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

import { ROUTE_EDIT_FRAMEWORK } from '../../constants';

export default {
  name: 'ComplianceFrameworkBadge',
  components: {
    GlLabel,
    GlButton,
    GlPopover,
  },
  props: {
    framework: {
      type: Object,
      required: true,
    },
    showDefault: {
      type: Boolean,
      required: false,
      default: true,
    },
    closeable: {
      type: Boolean,
      required: false,
      default: false,
    },
    showEdit: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    showDefaultBadge() {
      return this.showDefault && this.framework.default;
    },
    frameworkName() {
      const maxLength = 30;
      const name =
        this.framework?.name?.length > maxLength
          ? `${this.framework.name.substring(0, maxLength)}...`
          : this.framework.name;
      return this.showDefaultBadge ? `${name} (${this.$options.i18n.default})` : name;
    },
    frameworkTestId() {
      return this.showDefaultBadge
        ? 'compliance-framework-default-label'
        : 'compliance-framework-label';
    },
  },
  methods: {
    editFromPopover() {
      this.$router.push({ name: ROUTE_EDIT_FRAMEWORK, params: { id: this.framework.id } });
    },
  },
  i18n: {
    default: s__('ComplianceFrameworks|default'),
    edit: s__('ComplianceReport|Edit the framework'),
  },
};
</script>
<template>
  <div ref="badge">
    <gl-popover ref="popover" :target="() => $refs.label">
      <h5 v-if="framework.name" class="gl-text-left">{{ framework.name }}</h5>
      <p v-if="framework.description" class="gl-text-left">{{ framework.description }}</p>
      <div v-if="showEdit" class="gl-text-left">
        <gl-button
          category="tertiary"
          size="small"
          variant="confirm"
          class="gl-font-sm"
          @click="editFromPopover"
        >
          {{ $options.i18n.edit }}
        </gl-button>
      </div>
    </gl-popover>
    <span ref="label">
      <gl-label
        :data-testid="frameworkTestId"
        :background-color="framework.color"
        :title="frameworkName"
        :show-close-button="closeable"
        class="gl-md-max-w-26 gl-mt-3"
        @close="$emit('close')"
      />
    </span>
  </div>
</template>
