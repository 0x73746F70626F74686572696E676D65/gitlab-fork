<script>
import { GlAlert, GlButton, GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import {
  COUNTRIES_WITH_STATES_REQUIRED,
  COUNTRY_SELECT_PROMPT,
  STATE_SELECT_PROMPT,
  STEPS,
} from 'ee/subscriptions/constants';
import updateStateMutation from 'ee/subscriptions/graphql/mutations/update_state.mutation.graphql';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import SprintfWithLinks from 'ee/vue_shared/purchase_flow/components/checkout/sprintf_with_links.vue';
import { s__ } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';
import { CUSTOMERSDOT_CLIENT } from 'ee/subscriptions/buy_addons_shared/constants';
import getBillingAccountQuery from 'ee/vue_shared/purchase_flow/graphql/queries/get_billing_account.customer.query.graphql';
import { logError } from '~/lib/logger';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';
import BillingAccountDetails from 'ee/vue_shared/purchase_flow/components/checkout/billing_account_details.vue';

export default {
  components: {
    BillingAccountDetails,
    Step,
    GlAlert,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    SprintfWithLinks,
  },
  directives: {
    autofocusonshow,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      countries: [],
      billingAccount: null,
    };
  },
  apollo: {
    billingAccount: {
      client: CUSTOMERSDOT_CLIENT,
      query: getBillingAccountQuery,
      error(error) {
        this.handleError(error);
      },
    },
    customer: {
      query: stateQuery,
    },
    countries: {
      query: countriesQuery,
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.customer.country;
      },
      variables() {
        return {
          countryId: this.customer.country,
        };
      },
    },
  },
  computed: {
    countryModel: {
      get() {
        return this.customer.country;
      },
      set(country) {
        this.updateState({ customer: { country, state: null } });
      },
    },
    streetAddressLine1Model: {
      get() {
        return this.customer.address1;
      },
      set(address1) {
        this.updateState({ customer: { address1 } });
      },
    },
    streetAddressLine2Model: {
      get() {
        return this.customer.address2;
      },
      set(address2) {
        this.updateState({ customer: { address2 } });
      },
    },
    cityModel: {
      get() {
        return this.customer.city;
      },
      set(city) {
        this.updateState({ customer: { city } });
      },
    },
    countryStateModel: {
      get() {
        return this.customer.state;
      },
      set(state) {
        this.updateState({ customer: { state } });
      },
    },
    zipCodeModel: {
      get() {
        return this.customer.zipCode;
      },
      set(zipCode) {
        this.updateState({ customer: { zipCode } });
      },
    },
    shouldShowManageContacts() {
      return Boolean(this.billingAccount?.zuoraAccountName);
    },
    shouldShowBillingAccountDetails() {
      return this.shouldShowManageContacts;
    },
    stepTitle() {
      return this.shouldShowManageContacts
        ? this.$options.i18n.contactInformationStepTitle
        : this.$options.i18n.billingAddressStepTitle;
    },
    isStateRequired() {
      return COUNTRIES_WITH_STATES_REQUIRED.includes(this.customer.country);
    },
    isStateValid() {
      return this.isStateRequired ? !isEmpty(this.customer.state) : true;
    },
    areRequiredFieldsValid() {
      return (
        !isEmpty(this.customer.country) &&
        !isEmpty(this.customer.address1) &&
        !isEmpty(this.customer.city) &&
        !isEmpty(this.customer.zipCode)
      );
    },
    isValid() {
      if (this.shouldShowManageContacts) {
        return true;
      }

      return this.isStateValid && this.areRequiredFieldsValid;
    },
    countryOptionsWithDefault() {
      return [
        {
          name: COUNTRY_SELECT_PROMPT,
          id: null,
        },
        ...this.countries,
      ];
    },
    stateOptionsWithDefault() {
      return [
        {
          name: STATE_SELECT_PROMPT,
          id: null,
        },
        ...this.states,
      ];
    },
    selectedStateName() {
      if (!this.customer.state || !this.states) {
        return '';
      }

      return this.states.find((state) => state.id === this.customer.state).name;
    },
  },
  methods: {
    updateState(payload) {
      return this.$apollo
        .mutate({
          mutation: updateStateMutation,
          variables: {
            input: payload,
          },
        })
        .catch((error) => {
          this.$emit(PurchaseEvent.ERROR, error);
        });
    },
    handleError(error) {
      Sentry.captureException(error);
      logError(error);
    },
  },
  i18n: {
    billingAddressStepTitle: s__('Checkout|Billing address'),
    contactInformationStepTitle: s__('Checkout|Contact information'),
    nextStepButtonText: s__('Checkout|Continue to payment'),
    countryLabel: s__('Checkout|Country'),
    streetAddressLabel: s__('Checkout|Street address'),
    cityLabel: s__('Checkout|City'),
    stateLabel: s__('Checkout|State'),
    zipCodeLabel: s__('Checkout|Zip code'),
    manageContacts: s__(
      'Checkout|Manage the subscription and billing contacts for your billing account in the %{customersPortalLinkStart}Customers Portal%{customersPortalLinkEnd}. Learn more about %{manageContactsLinkStart}how to manage your contacts%{manageContactsLinkEnd}.',
    ),
    editCustomersPortalText: s__('Checkout|Edit in Customers Portal'),
  },
  manageContactsLinkObject: {
    customersPortalLink: gon.subscriptions_url,
    manageContactsLink: helpPagePath(
      'subscriptions/customers_portal#subscription-and-billing-contacts',
    ),
  },
  stepId: STEPS[1].id,
  billingAccountsUrl: gon.billing_accounts_url,
};
</script>
<template>
  <step
    v-if="!$apollo.loading.customer"
    :step-id="$options.stepId"
    :title="stepTitle"
    :is-valid="isValid"
    :next-step-button-text="$options.i18n.nextStepButtonText"
  >
    <template #body>
      <div v-if="shouldShowManageContacts" class="gl-mb-3">
        <gl-alert :dismissible="false" class="gl-my-5" variant="tip">
          <sprintf-with-links
            :message="$options.i18n.manageContacts"
            :link-object="$options.manageContactsLinkObject"
          />
        </gl-alert>

        <billing-account-details
          v-if="shouldShowBillingAccountDetails"
          :billing-account="billingAccount"
        />
      </div>

      <div v-else data-testid="checkout-billing-address-form">
        <gl-form-group
          v-if="!$apollo.loading.countries"
          :label="$options.i18n.countryLabel"
          label-size="sm"
          class="mb-3"
        >
          <gl-form-select
            v-model="countryModel"
            v-autofocusonshow
            :options="countryOptionsWithDefault"
            class="js-country"
            value-field="id"
            text-field="name"
            data-testid="country"
          />
        </gl-form-group>
        <gl-form-group :label="$options.i18n.streetAddressLabel" label-size="sm" class="mb-3">
          <gl-form-input
            v-model="streetAddressLine1Model"
            type="text"
            data-testid="street-address-1"
          />
          <gl-form-input
            v-model="streetAddressLine2Model"
            type="text"
            data-testid="street-address-2"
            class="gl-mt-3"
          />
        </gl-form-group>
        <gl-form-group :label="$options.i18n.cityLabel" label-size="sm" class="mb-3">
          <gl-form-input v-model="cityModel" type="text" data-testid="city" />
        </gl-form-group>
        <div class="combined gl-display-flex">
          <gl-form-group
            v-if="!$apollo.loading.states && states"
            :label="$options.i18n.stateLabel"
            label-size="sm"
            class="mr-3 w-50"
          >
            <gl-form-select
              v-model="countryStateModel"
              :options="stateOptionsWithDefault"
              value-field="id"
              text-field="name"
              data-testid="state"
            />
          </gl-form-group>
          <gl-form-group :label="$options.i18n.zipCodeLabel" label-size="sm" class="w-50">
            <gl-form-input v-model="zipCodeModel" type="text" data-testid="zip-code" />
          </gl-form-group>
        </div>
      </div>
    </template>
    <template #summary>
      <billing-account-details
        v-if="shouldShowBillingAccountDetails"
        :billing-account="billingAccount"
      />

      <div v-else-if="!shouldShowManageContacts" data-testid="checkout-billing-address-summary">
        <div class="js-summary-line-1">{{ customer.address1 }}</div>
        <div class="js-summary-line-2">{{ customer.address2 }}</div>
        <div class="js-summary-line-3">
          {{ customer.city }}, {{ customer.country }} {{ selectedStateName }} {{ customer.zipCode }}
        </div>
      </div>
    </template>

    <template v-if="shouldShowBillingAccountDetails" #footer>
      <gl-button
        variant="default"
        category="primary"
        data-testid="billing-address-cdot-edit"
        :href="$options.billingAccountsUrl"
        target="_blank"
      >
        {{ $options.i18n.editCustomersPortalText }}
      </gl-button>
    </template>
  </step>
</template>
