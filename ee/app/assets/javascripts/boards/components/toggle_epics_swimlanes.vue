<script>
import { GlToggle } from '@gitlab/ui';

export default {
  components: {
    GlToggle,
  },
  props: {
    isSwimlanesOn: {
      type: Boolean,
      required: true,
    },
  },
};
</script>

<template>
  <gl-toggle
    :value="isSwimlanesOn"
    :label="__('Epic swimlanes')"
    label-position="left"
    data-testid="epic-swimlanes-toggle"
    class="board-dropdown-toggle gl-flex-direction-row gl-justify-between gl-w-full"
  />
</template>
