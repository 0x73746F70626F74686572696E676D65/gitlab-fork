<script>
import { CUSTOM_ACTION_KEY } from '../constants';
import ScanAction from './scan_action.vue';
import CodeBlockAction from './code_block_action.vue';

export default {
  name: 'ActionSection',
  components: {
    ScanAction,
    CodeBlockAction,
  },
  props: {
    initAction: {
      type: Object,
      required: true,
    },
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    isCustomAction() {
      return this.initAction?.scan === CUSTOM_ACTION_KEY;
    },
  },
  methods: {
    updateAction(event) {
      this.$emit('changed', event);
    },
    removeAction() {
      this.$emit('remove');
    },
    parseError() {
      this.$emit('parsing-error');
    },
  },
};
</script>

<template>
  <scan-action
    v-if="!isCustomAction"
    class="gl-mb-4"
    :init-action="initAction"
    :action-index="actionIndex"
    :error-sources="errorSources"
    @changed="updateAction"
    @remove="removeAction"
    @parsing-error="parseError"
  />

  <code-block-action
    v-else
    class="gl-mb-4"
    :action-index="actionIndex"
    :init-action="initAction"
    @changed="updateAction"
    @remove="removeAction"
  />
</template>
