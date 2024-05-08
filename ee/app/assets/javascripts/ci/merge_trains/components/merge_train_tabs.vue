<script>
import { GlTab, GlTabs } from '@gitlab/ui';

export default {
  name: 'MergeTrainTabs',
  components: {
    GlTab,
    GlTabs,
  },
};
</script>

<template>
  <gl-tabs lazy>
    <gl-tab
      :title="s__('Pipelines|Active train')"
      data-testid="active-trains-tab"
      @click="$emit('activeTabClicked')"
    >
      <slot name="active"></slot>
    </gl-tab>
    <gl-tab
      :title="s__('Pipelines|Merged')"
      data-testid="merged-trains-tab"
      @click="$emit('mergedTabClicked')"
    >
      <slot name="merged"></slot>
    </gl-tab>
  </gl-tabs>
</template>
