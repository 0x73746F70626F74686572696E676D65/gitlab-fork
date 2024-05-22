<script>
import { v4 as uuidv4 } from 'uuid';
import { isEqual, isObject } from 'lodash';
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import Api from 'ee/api';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import activeStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/active_step.query.graphql';
import PrivacyAndTermsConfirm from 'ee/subscriptions/shared/components/privacy_and_terms_confirm.vue';
import { ActiveModelError } from '~/lib/utils/error_utils';
import { extractErrorCode } from 'ee/vue_shared/purchase_flow/zuora_utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';
import { STEPS } from 'ee/subscriptions/constants';

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
      isActive: false,
      isLoading: false,
      orderParams: {},
    };
  },
  computed: {
    idempotencyKeyParams() {
      return [this.paymentMethodId, this.planId, this.quantity, this.selectedGroup, this.zipCode];
    },
    serializedKey() {
      return JSON.stringify(this.idempotencyKeyParams);
    },
    paymentMethodId() {
      return this.orderParams?.subscription?.payment_method_id;
    },
    planId() {
      return this.orderParams?.subscription?.plan_id;
    },
    quantity() {
      return this.orderParams?.subscription?.quantity;
    },
    shouldDisableConfirmOrder() {
      return !this.didAcceptTerms || this.isLoading;
    },
    selectedGroup() {
      return this.orderParams?.selected_group;
    },
    zipCode() {
      return this.orderParams?.customer?.zip_code;
    },
  },
  watch: {
    idempotencyKeyParams: {
      handler(newValue, oldValue) {
        if (!isEqual(newValue, oldValue)) {
          this.updateIdempotencyKey();
        }
      },
    },
  },
  created() {
    this.updateIdempotencyKey();
  },
  apollo: {
    isActive: {
      query: activeStepQuery,
      update: ({ activeStep }) => activeStep?.id === STEPS[3].id,
      error: (error) => {
        this.$emit(PurchaseEvent.ERROR, error);
      },
    },
    orderParams: {
      query: stateQuery,
      skip() {
        return !this.isActive;
      },
      update(data) {
        const { customer } = data;
        const { name } = data.activeSubscription;
        return {
          setup_for_company: data.isSetupForCompany,
          selected_group: data.selectedNamespaceId,
          new_user: data.isNewUser,
          redirect_after_success: data.redirectAfterSuccess,
          active_subscription: name,
          customer: {
            country: customer.country,
            address_1: customer.address1,
            address_2: customer.address2,
            city: customer.city,
            state: customer.state,
            zip_code: customer.zipCode,
            company: customer.company,
          },
          subscription: {
            quantity: data.subscription.quantity,
            is_addon: data.selectedPlan.isAddon,
            plan_id: data.selectedPlan.id,
            payment_method_id: data.paymentMethod.id,
          },
        };
      },
    },
  },
  methods: {
    getConfirmOrderParams() {
      return {
        ...this.orderParams,
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
    confirmOrder() {
      this.isLoading = true;
      return Api.confirmOrder(this.getConfirmOrderParams())
        .then(({ data }) => {
          if (data?.location) {
            visitUrl(data.location);
          } else {
            if (data?.error_attribute_map) {
              throw new ActiveModelError(data.error_attribute_map, JSON.stringify(data.errors));
            } else if (isObject(data.errors)) {
              const { code, attributes, message } = data?.errors || {};
              throw Object.assign(new Error(message), { code, attributes });
            }

            throw new Error(data.errors);
          }
        })
        .catch((error = {}) => {
          const { status } = error.response || {};
          // Regenerate the idempotency key on client-side errors, to ensure the server regards the new request.
          // Context: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/129830#note_1522796835.
          if (this.isClientSideError(status)) {
            this.regenerateIdempotencyKey();
          }

          const cause = extractErrorCode(error.message);
          this.$emit(PurchaseEvent.ERROR, Object.assign(error, { cause }));
        })
        .finally(() => {
          this.isLoading = false;
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
  <div v-if="isActive" class="full-width gl-mb-7" data-testid="confirm-order-root">
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
      <gl-loading-icon v-if="isLoading" inline size="sm" />
      {{ isLoading ? $options.i18n.confirming : $options.i18n.confirm }}
    </gl-button>
  </div>
</template>
