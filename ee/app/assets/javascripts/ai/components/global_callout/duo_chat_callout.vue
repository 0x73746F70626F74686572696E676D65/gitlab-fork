<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import DUO_CHAT_ILLUSTRATION from './popover-gradient.svg?url';

export const DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS = 'js-tanuki-bot-chat-toggle';

const i18n = {
  POPOVER_LABEL: s__('DuoChat|GitLab Duo Chat'),
  POPOVER_DESCRIPTION: s__('DuoChat|Use AI to answer questions about things like:'),
  POPOVER_LIST_ITEMS: [
    s__("DuoChat|The issue, epic, or code you're viewing"),
    s__('DuoChat|How to use GitLab'),
  ],
  POPOVER_BUTTON: __('Ask GitLab Duo'),
};

export default {
  name: 'DuoChatCallout',
  components: {
    GlPopover,
    GlLink,
    UserCalloutDismisser,
  },

  beforeMount() {
    const allButtons = Array.from(
      document.querySelectorAll(`.${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}`),
    );

    this.popoverTarget = allButtons.find((button) => {
      const style = window.getComputedStyle(button);
      return style.display !== 'none' && style.visibility !== 'hidden';
    });
  },
  mounted() {
    this.popoverTarget?.addEventListener('click', this.handleButtonClick);
  },
  beforeDestroy() {
    this.stopListeningToPopover();
  },
  methods: {
    handleButtonClick() {
      if (this.$refs.popoverLink) {
        this.$refs.popoverLink.$emit('click');
      }
    },
    stopListeningToPopover() {
      if (this.popoverTarget) {
        this.popoverTarget.removeEventListener('click', this.handleButtonClick);
      }
    },
    dismissCallout(dismissFn) {
      this.stopListeningToPopover();
      dismissFn();
    },
    notifyAboutDismiss() {
      this.$emit('callout-dismissed');
    },
    dismissAndNotify(dismissFn) {
      this.dismissCallout(dismissFn);
      this.notifyAboutDismiss();
    },
  },
  DUO_CHAT_ILLUSTRATION,
  i18n,
};
</script>
<template>
  <user-callout-dismisser v-if="popoverTarget" feature-name="duo_chat_callout">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-popover
        v-if="shouldShowCallout"
        :target="popoverTarget"
        :show="shouldShowCallout"
        show-close-button
        :css-classes="['duo-chat-callout-popover', 'gl-max-w-48', 'gl-shadow-lg', 'gl-p-2']"
        triggers="manual"
        data-testid="duo-chat-promo-callout-popover"
        @close-button-clicked="dismissCallout(dismiss)"
      >
        <img
          :src="$options.DUO_CHAT_ILLUSTRATION"
          :alt="''"
          class="gl-absolute gl-top-0 gl-left-0 gl-w-full gl-pointer-events-none"
        />
        <h5 class="gl-my-3 gl-mr-3">
          {{ $options.i18n.POPOVER_LABEL }}
        </h5>
        <p class="gl-m-0 gl-w-7/10" data-testid="duo-chat-callout-description">
          {{ $options.i18n.POPOVER_DESCRIPTION }}
        </p>
        <ul class="gl-pt-3 gl-pl-5">
          <li v-for="item in $options.i18n.POPOVER_LIST_ITEMS" :key="item">{{ item }}</li>
        </ul>
        <gl-link
          ref="popoverLink"
          class="gl-button btn btn-confirm block gl-mb-2 gl-mt-4"
          variant="confirm"
          category="primary"
          target="_blank"
          block
          @click="dismissAndNotify(dismiss)"
        >
          {{ $options.i18n.POPOVER_BUTTON }}
        </gl-link>
      </gl-popover>
    </template>
  </user-callout-dismisser>
</template>
