<script>
import { uniqueId } from 'lodash';
import { PQL_BUTTON_TEXT } from '../constants';
import HandRaiseLeadButton from './hand_raise_lead_button.vue';
import HandRaiseLeadModal from './hand_raise_lead_modal.vue';

export default {
  name: 'HandRaiseLead',
  components: {
    HandRaiseLeadButton,
    HandRaiseLeadModal,
  },
  inject: {
    createHandRaiseLeadPath: {},
    user: {
      default: {},
    },
    buttonAttributes: {
      default: {},
    },
    buttonText: {
      default: PQL_BUTTON_TEXT,
    },
    ctaTracking: {
      default: {},
    },
    glmContent: {},
    productInteraction: {},
  },
  data() {
    return { isLoading: false, modalId: uniqueId('hand-raise-lead-modal-') };
  },
  methods: {
    updateLoading(value) {
      this.isLoading = value;
    },
  },
};
</script>

<template>
  <div>
    <hand-raise-lead-button
      :modal-id="modalId"
      :button-attributes="buttonAttributes"
      :button-text="buttonText"
      :glm-content="glmContent"
      :product-interaction="productInteraction"
      :cta-tracking="ctaTracking"
      :is-loading="isLoading"
    />

    <hand-raise-lead-modal
      :user="user"
      :submit-path="createHandRaiseLeadPath"
      :modal-id="modalId"
      @loading="updateLoading"
    />
  </div>
</template>
