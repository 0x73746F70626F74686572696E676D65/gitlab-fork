<script>
import { GlTooltipDirective, GlIcon } from '@gitlab/ui';
import { I18N_CELL_FLAG_TRUE_TEXT, I18N_CELL_FLAG_FALSE_TEXT } from '../constants';

export default {
  name: 'DevopsAdoptionTableCellFlag',
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    withText: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    tooltipText() {
      return this.enabled ? I18N_CELL_FLAG_TRUE_TEXT : I18N_CELL_FLAG_FALSE_TEXT;
    },
  },
};
</script>
<template>
  <div>
    <div v-if="enabled" class="gl-display-flex gl-justify-content-end gl-sm-justify-content-start">
      <gl-icon
        name="status_success_solid"
        class="gl-text-green-500"
        :class="{ 'gl-mr-3': withText }"
      />
      <div v-if="withText">{{ __('Adopted') }}</div>
    </div>
    <div v-if="!enabled" class="gl-display-flex gl-justify-content-end gl-sm-justify-content-start">
      <gl-icon name="issue-open-m" class="gl-text-gray-500" :class="{ 'gl-mr-3': withText }" />
      <div v-if="withText">{{ __('Not adopted') }}</div>
    </div>
  </div>
</template>
