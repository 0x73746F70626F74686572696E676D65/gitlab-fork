<script>
import { ACTION_AND_LABEL } from '../../constants';
import { REQUIRE_APPROVAL_TYPE, DISABLED_BOT_MESSAGE_ACTION } from '../lib';
import ApproverAction from './approver_action.vue';
import BotMessageAction from './bot_message_action.vue';

export default {
  ACTION_AND_LABEL,
  DISABLED_BOT_MESSAGE_ACTION,
  name: 'ActionSection',
  components: {
    ApproverAction,
    BotMessageAction,
  },
  props: {
    actionIndex: {
      type: Number,
      required: true,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    initAction: {
      type: Object,
      required: true,
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isApproverAction() {
      return this.initAction.type === REQUIRE_APPROVAL_TYPE;
    },
    isFirstAction() {
      return this.actionIndex === 0;
    },
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-text-gray-500 gl-mb-4 gl-ml-5"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>
    <approver-action
      v-if="isApproverAction"
      :init-action="initAction"
      :errors="errors"
      :existing-approvers="existingApprovers"
      @error="$emit('error')"
      @updateApprovers="$emit('updateApprovers', $event)"
      @changed="$emit('changed', $event)"
      @remove="$emit('remove')"
    />
    <bot-message-action
      v-else
      :init-action="initAction"
      @remove="$emit('changed', $options.DISABLED_BOT_MESSAGE_ACTION)"
    />
  </div>
</template>
