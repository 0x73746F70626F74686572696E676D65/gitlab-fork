<script>
import { GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';

export default {
  components: {
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  props: {
    value: {
      type: String,
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    selected: {
      type: Boolean,
      required: true,
    },
  },
};
</script>
<template>
  <gl-filtered-search-suggestion :value="value">
    <div :data-testid="`${name}-search-token-suggestion-${value}`" class="gl-flex gl-items-center">
      <gl-icon
        name="check"
        class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
        :class="{ 'gl-invisible': !selected }"
        :data-testid="`${name}-icon-${value}`"
      />
      {{ text }}
    </div>
  </gl-filtered-search-suggestion>
</template>
