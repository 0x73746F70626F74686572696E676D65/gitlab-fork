<script>
import { GlBadge, GlTab, GlTabs } from '@gitlab/ui';

export default {
  name: 'MergeTrainTabs',
  components: {
    GlBadge,
    GlTab,
    GlTabs,
  },
  props: {
    activeTrain: {
      type: Object,
      required: true,
    },
    mergedTrain: {
      type: Object,
      required: true,
    },
  },
  computed: {
    activeCarCount() {
      return this.activeTrain?.cars?.count || 0;
    },
    mergedCarCount() {
      return this.mergedTrain?.cars?.count || 0;
    },
  },
};
</script>

<template>
  <gl-tabs lazy>
    <gl-tab data-testid="active-cars-tab" @click="$emit('activeTabClicked')">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Active') }}</span>
        <gl-badge size="sm">
          {{ activeCarCount }}
        </gl-badge>
      </template>
      <slot name="active"></slot>
    </gl-tab>
    <gl-tab data-testid="merged-cars-tab" @click="$emit('mergedTabClicked')">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Merged') }}</span>
        <gl-badge size="sm">
          {{ mergedCarCount }}
        </gl-badge>
      </template>
      <slot name="merged"></slot>
    </gl-tab>
  </gl-tabs>
</template>
