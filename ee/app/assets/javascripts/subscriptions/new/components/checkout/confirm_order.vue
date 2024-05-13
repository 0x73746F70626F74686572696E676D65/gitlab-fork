<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { v4 as uuidv4 } from 'uuid';
import { isEqual, isObject } from 'lodash';
import { STEPS } from 'ee/subscriptions/constants';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';
import activeStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/active_step.query.graphql';
import { s__, sprintf } from '~/locale';
import Api from 'ee/api';
import { trackTransaction } from 'ee/google_tag_manager';
import Tracking from '~/tracking';
import { addExperimentContext } from '~/tracking/utils';
import { ActiveModelError } from '~/lib/utils/error_utils';
import { isInvalidPromoCodeError } from 'ee/subscriptions/new/utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { extractErrorCode } from 'ee/vue_shared/purchase_flow/zuora_utils';
import PrivacyAndTermsConfirm from 'ee/subscriptions/shared/components/privacy_and_terms_confirm.vue';

export default {
  components: {
    GlButton,
    GlLoadingIcon,
    PrivacyAndTermsConfirm,
  },
  data() {
    return {
      didAcceptTerms: false,
      idempotencyKeys: {},
      isActive: {},
      isConfirmingOrder: false,
    };
  },
  apollo: {
    isActive: {
      query: activeStepQuery,
      update: ({ activeStep }) => activeStep?.id === STEPS[3].id,
      error: (error) => this.handleError(error),
    },
  },
  computed: {
    ...mapGetters([
      'hasValidPriceDetails',
      'confirmOrderParams',
      'totalExVat',
      'vat',
      'selectedPlanDetails',
    ]),
    shouldDisableConfirmOrder() {
      if (!this.didAcceptTerms) {
        return true;
      }
      return this.isConfirmingOrder || !this.hasValidPriceDetails;
    },
    idempotencyKeyParams() {
      return [this.paymentMethodId, this.planId, this.quantity, this.selectedGroup, this.zipCode];
    },
    serializedKey() {
      return JSON.stringify(this.idempotencyKeyParams);
    },
    paymentMethodId() {
      return this.confirmOrderParams?.subscription?.payment_method_id;
    },
    planId() {
      return this.confirmOrderParams?.subscription?.plan_id;
    },
    quantity() {
      return this.confirmOrderParams?.subscription?.quantity;
    },
    selectedGroup() {
      return this.confirmOrderParams?.selected_group;
    },
    zipCode() {
      return this.confirmOrderParams?.customer?.zip_code;
    },
  },
  watch: {
    idempotencyKeyParams: {
      handler(newValue, oldValue) {
        if (!isEqual(newValue, oldValue)) {
          this.updateIdempotencyKey();
        }
      },
      deep: true,
    },
  },
  created() {
    this.updateIdempotencyKey();
  },
  methods: {
    getOrderParams() {
      return {
        ...this.confirmOrderParams,
        idempotency_key: this.idempotencyKeys[this.serializedKey],
      };
    },
    updateIdempotencyKey() {
      this.idempotencyKeys[this.serializedKey] =
        this.idempotencyKeys[this.serializedKey] ?? uuidv4();
    },
    regenerateIdempotencyKey() {
      this.idempotencyKeys[this.serializedKey] = uuidv4();
    },
    isClientSideError(status) {
      return status >= 400 && status < 500;
    },
    handleError(error) {
      this.$emit(PurchaseEvent.ERROR, error);
    },
    trackConfirmOrder(message) {
      Tracking.event(
        'default',
        'click_button',
        addExperimentContext({ label: 'confirm_purchase', property: message }),
      );
    },
    shouldShowErrorMessageOnly(errors) {
      if (!errors?.message) {
        return false;
      }

      return isInvalidPromoCodeError(errors);
    },
    confirmOrder() {
      this.isConfirmingOrder = true;

      const orderParams = this.getOrderParams();

      Api.confirmOrder(orderParams)
        .then(({ data }) => {
          if (data?.location) {
            const transactionDetails = {
              paymentOption: orderParams?.subscription?.payment_method_id,
              revenue: this.totalExVat,
              tax: this.vat,
              selectedPlan: this.selectedPlanDetails?.value,
              quantity: orderParams?.subscription?.quantity,
            };

            trackTransaction(transactionDetails);
            this.trackConfirmOrder(s__('Checkout|Success: subscription'));

            visitUrl(data.location);
          } else {
            if (data?.name) {
              const errorMessage = sprintf(
                s__('Checkout|Name: %{errorMessage}'),
                { errorMessage: data.name.join(', ') },
                false,
              );
              throw new Error(errorMessage);
            } else if (data?.error_attribute_map) {
              throw new ActiveModelError(data.error_attribute_map, JSON.stringify(data.errors));
            } else if (isObject(data?.errors)) {
              const { code, attributes, message } = data?.errors || {};
              throw Object.assign(new Error(message), { code, attributes });
            }

            throw new Error(data?.errors);
          }
        })
        .catch((error = {}) => {
          const { status } = error.response || {};
          // Regenerate the idempotency key on client-side errors, to ensure the server regards the new request.
          // Context: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/129830#note_1522796835.
          if (this.isClientSideError(status)) {
            this.regenerateIdempotencyKey();
          }
          this.trackConfirmOrder(error.message);
          const cause = extractErrorCode(error.message);
          this.handleError(Object.assign(error, { cause }));
        })
        .finally(() => {
          this.isConfirmingOrder = false;
        });
    },
  },
  i18n: {
    confirm: s__('Checkout|Confirm purchase'),
    confirming: s__('Checkout|Confirming...'),
  },
};
</script>
<template>
  <div v-if="isActive" class="full-width gl-mt-5 gl-mb-7">
    <privacy-and-terms-confirm
      v-model="didAcceptTerms"
      class="mb-2"
      data-testid="privacy-and-terms-confirm"
    />
    <gl-button
      :disabled="shouldDisableConfirmOrder"
      variant="confirm"
      category="primary"
      @click="confirmOrder"
    >
      <gl-loading-icon v-if="isConfirmingOrder" inline size="sm" />
      {{ isConfirmingOrder ? $options.i18n.confirming : $options.i18n.confirm }}
    </gl-button>
  </div>
</template>
