<script>
import { GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { __ } from '~/locale';
import { ANY_OPERATOR } from '../../constants';
import { enforceIntValue } from '../../utils';

export default {
  components: {
    GlCollapsibleListbox,
    GlFormInput,
  },
  props: {
    value: {
      type: Number,
      required: false,
      default: 0,
    },
    id: {
      type: String,
      required: true,
    },
    label: {
      type: String,
      required: true,
    },
    operators: {
      type: Array,
      required: true,
    },
    selected: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      operator: this.selected || this.operators[0]?.value,
    };
  },
  computed: {
    showNumberInput() {
      return this.operator !== ANY_OPERATOR;
    },
    inputId() {
      return `${this.id}-number-range-input`;
    },
  },
  methods: {
    onSelect(item) {
      this.operator = item;
      this.$emit('operator-change', item);
    },
    onValueChange(value) {
      this.$emit('input', enforceIntValue(value));
    },
  },
  i18n: {
    headerText: __('Choose an option'),
  },
};
</script>

<template>
  <div class="gl-display-flex gl-gap-3">
    <gl-collapsible-listbox
      :items="operators"
      :header-text="$options.i18n.headerText"
      :selected="operator"
      :data-testid="`${id}-operator`"
      @select="onSelect"
    >
      <template #list-item="{ item }">
        {{ item.text }}
      </template>
    </gl-collapsible-listbox>
    <template v-if="showNumberInput">
      <label :for="inputId" class="gl-sr-only">{{ label }}</label>
      <gl-form-input
        :id="inputId"
        :value="value"
        type="number"
        class="!gl-w-11"
        :min="0"
        :data-testid="`${id}-input`"
        @input="onValueChange"
      />
    </template>
  </div>
</template>
