<script>
import { GlCollapsibleListbox, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import SectionLayout from './section_layout.vue';

export default {
  i18n: {
    disabledLabel: __('disabled'),
  },
  name: 'ScanFilterSelector',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SectionLayout,
    GlCollapsibleListbox,
    GlBadge,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    filters: {
      type: Array,
      required: false,
      default: () => [],
    },
    selected: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    shouldDisableFilter: {
      type: Function,
      required: false,
      default: () => false,
    },
    buttonText: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Add new criteria'),
    },
    header: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Choose criteria type'),
    },
    tooltipTitle: {
      type: String,
      required: false,
      default: '',
    },
    customFilterTooltip: {
      type: Function,
      required: false,
      default: () => null,
    },
  },
  methods: {
    filterDisabled(value) {
      return this.shouldDisableFilter(value) || Boolean(this.selected[value]);
    },
    selectFilter(filter) {
      if (this.filterDisabled(filter)) {
        return;
      }

      this.$emit('select', filter);
    },
    filterTooltip(filter) {
      return this.customFilterTooltip(filter) || filter.tooltip;
    },
  },
};
</script>

<template>
  <section-layout :show-remove-button="false">
    <template #content>
      <gl-collapsible-listbox
        v-gl-tooltip.right.viewport
        :disabled="disabled"
        fluid-width
        :header-text="header"
        :items="filters"
        :toggle-text="buttonText"
        :title="tooltipTitle"
        selected="selected"
        variant="link"
        @select="selectFilter"
      >
        <template #list-item="{ item }">
          <div class="gl-display-flex">
            <span
              :id="item.value"
              class="gl-pr-3"
              :class="{ 'gl-text-gray-500': filterDisabled(item.value) }"
            >
              {{ item.text }}
            </span>
            <gl-badge
              v-if="filterDisabled(item.value)"
              v-gl-tooltip.right.viewport
              class="gl-ml-auto"
              variant="neutral"
              :title="filterTooltip(item)"
            >
              {{ $options.i18n.disabledLabel }}
            </gl-badge>
          </div>
        </template>
      </gl-collapsible-listbox>
    </template>
  </section-layout>
</template>
