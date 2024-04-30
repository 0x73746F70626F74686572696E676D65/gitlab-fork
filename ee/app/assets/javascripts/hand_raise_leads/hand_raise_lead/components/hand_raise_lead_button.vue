<script>
import { GlButton } from '@gitlab/ui';
import Tracking from '~/tracking';
import { PQL_HAND_RAISE_MODAL_TRACKING_LABEL } from 'ee/hand_raise_leads/hand_raise_lead/constants';
import eventHub from '../event_hub';

export default {
  name: 'HandRaiseLeadButton',
  components: {
    GlButton,
  },
  mixins: [Tracking.mixin()],
  props: {
    ctaTracking: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    modalId: {
      type: String,
      required: true,
    },
    buttonText: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    buttonAttributes: {
      type: Object,
      required: true,
    },
    glmContent: {
      type: String,
      required: true,
    },
    productInteraction: {
      type: String,
      required: true,
    },
  },
  computed: {
    tracking() {
      return {
        label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
        experiment: this.ctaTracking.experiment,
      };
    },
  },
  methods: {
    openModal() {
      this.trackBtnClick();

      eventHub.$emit('openModal', {
        productInteraction: this.productInteraction,
        ctaTracking: this.ctaTracking,
        glmContent: this.glmContent,
        modalIdToOpen: this.modalId,
      });
    },
    trackBtnClick() {
      const { action, ...options } = this.ctaTracking;
      if (action) {
        this.track(action, options);
      }
    },
  },
};
</script>

<template>
  <gl-button v-bind="buttonAttributes" :loading="isLoading" @click="openModal">
    {{ buttonText }}
  </gl-button>
</template>
