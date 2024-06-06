<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import {
  CUSTOM_STRATEGY_OPTIONS,
  CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS,
  INJECT,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { validateStrategyValues } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

export default {
  CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS,
  name: 'CodeBlockStrategySelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    strategy: {
      type: String,
      required: false,
      default: INJECT,
      validator: validateStrategyValues,
    },
  },
  computed: {
    toggleText() {
      return CUSTOM_STRATEGY_OPTIONS[this.strategy];
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    label-for="file-path"
    :items="$options.CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS"
    :toggle-text="toggleText"
    :selected="strategy"
    @select="$emit('select', $event)"
  />
</template>
