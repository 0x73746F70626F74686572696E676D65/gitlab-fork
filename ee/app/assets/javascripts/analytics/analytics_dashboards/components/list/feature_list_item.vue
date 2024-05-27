<script>
import { uniqueId } from 'lodash';
import { GlIcon, GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'FeatureListItem',
  components: {
    GlButton,
    GlIcon,
    GlBadge,
    GlPopover,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    to: {
      type: String,
      required: true,
    },
    badgeText: {
      type: String,
      required: false,
      default: null,
    },
    badgePopoverText: { type: String, required: false, default: null },
    actionText: {
      type: String,
      required: false,
      default: __('Set up'),
    },
  },
  featureAvatarColor: 1,
  badgeId: uniqueId('badge-'),
};
</script>

<template>
  <li class="gl-display-flex! gl-px-5! gl-align-items-center">
    <div class="gl-float-left gl-mr-4 gl-display-flex gl-align-items-center">
      <gl-icon name="cloud-gear" class="gl-text-gray-200 gl-mr-3" :size="16" />
    </div>
    <div
      class="gl-display-flex gl-align-items-center gl-justify-content-space-between gl-flex-grow-1"
    >
      <div class="gl-display-flex gl-flex-direction-column">
        <strong class="gl-text-gray-300">
          {{ title }}
        </strong>
        <p class="gl-leading-normal gl-m-0 gl-text-gray-300">
          {{ description }}
        </p>
      </div>
      <div class="gl-float-right">
        <template v-if="badgeText">
          <gl-badge :id="$options.badgeId">{{ badgeText }}</gl-badge>
          <gl-popover v-if="badgePopoverText" :target="$options.badgeId">{{
            badgePopoverText
          }}</gl-popover>
        </template>
        <gl-button data-testid="setup-button" :to="to">{{ actionText }}</gl-button>
      </div>
    </div>
  </li>
</template>
