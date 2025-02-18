<script>
import { GlSprintf, GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { EXCEPTION_TYPE_ITEMS, NO_EXCEPTION_KEY, EXCEPTION_KEY } from './constants';
import BranchSelector from './branch_selector.vue';

export default {
  EXCEPTION_TYPE_ITEMS,
  NO_EXCEPTION_KEY,
  i18n: {
    exceptionText: s__('SecurityOrchestration|with %{exceptionType} on %{branchSelector}'),
    noExceptionText: s__('SecurityOrchestration|with %{exceptionType}'),
  },
  name: 'BranchExceptionSelector',
  components: {
    GlCollapsibleListbox,
    GlSprintf,
    BranchSelector,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    selectedExceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      selectedExceptionType: this.selectedExceptions.length > 0 ? EXCEPTION_KEY : NO_EXCEPTION_KEY,
    };
  },
  computed: {
    exceptionText() {
      return this.selectedExceptionType === EXCEPTION_KEY
        ? this.$options.i18n.exceptionText
        : this.$options.i18n.noExceptionText;
    },
    isGroup() {
      return isGroup(this.namespaceType);
    },
  },
  methods: {
    setExceptionType(type) {
      this.selectedExceptionType = type;

      if (type === NO_EXCEPTION_KEY) {
        this.$emit('remove');
      }
    },
    selectExceptions(value) {
      this.$emit('select', { branch_exceptions: value });
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-align-items-center gl-gap-3">
    <gl-sprintf :message="exceptionText">
      <template #exceptionType>
        <gl-collapsible-listbox
          :items="$options.EXCEPTION_TYPE_ITEMS"
          :selected="selectedExceptionType"
          @select="setExceptionType"
        />
      </template>

      <template #branchSelector>
        <branch-selector
          :is-group="isGroup"
          :selected-exceptions="selectedExceptions"
          @select-branches="selectExceptions"
        />
      </template>
    </gl-sprintf>
  </div>
</template>
