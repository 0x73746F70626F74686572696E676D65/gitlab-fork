<script>
import { GlButton, GlCollapse } from '@gitlab/ui';

export default {
  components: {
    GlButton,
    GlCollapse,
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
    expandable: {
      type: Boolean,
      required: false,
      default: false,
    },
    initiallyExpanded: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data(props) {
    return {
      isExpanded: props.initiallyExpanded,
    };
  },

  computed: {
    isCurrentlyExpanded() {
      return !this.expandable || this.isExpanded;
    },
  },

  methods: {
    toggleExpand() {
      this.isExpanded = !this.isExpanded;
    },
  },
};
</script>
<template>
  <div>
    <div
      class="gl-display-flex gl-bg-gray-10 gl-p-4 gl-my-4 gl-align-items-center"
      :class="{
        'gl-cursor-pointer': expandable,
      }"
      @click="toggleExpand"
    >
      <div class="gl-flex-grow-1">
        <div class="gl-font-bold gl-font-size-h2">
          {{ title }}
        </div>
        <span>{{ description }}</span>
      </div>
      <gl-button v-if="expandable" @click.stop="toggleExpand">
        {{ isExpanded ? __('Collapse') : __('Expand') }}
      </gl-button>
    </div>
    <gl-collapse :visible="isCurrentlyExpanded" class="gl-p-4">
      <slot></slot>
    </gl-collapse>
  </div>
</template>
