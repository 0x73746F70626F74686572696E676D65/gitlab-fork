<script>
import { GlAlert, GlButton, GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';
import { isEmpty } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import {
  STEP_BILLING_ADDRESS,
  COUNTRIES_WITH_STATES_REQUIRED,
  COUNTRY_SELECT_PROMPT,
  STATE_SELECT_PROMPT,
} from 'ee/subscriptions/constants';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import BillingAccountDetails from 'ee/vue_shared/purchase_flow/components/checkout/billing_account_details.vue';
import { s__ } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import Tracking from '~/tracking';
import getBillingAccountQuery from 'ee/vue_shared/purchase_flow/graphql/queries/get_billing_account.customer.query.graphql';
import { CUSTOMERSDOT_CLIENT } from 'ee/subscriptions/buy_addons_shared/constants';
import { logError } from '~/lib/logger';
import SprintfWithLinks from 'ee/vue_shared/purchase_flow/components/checkout/sprintf_with_links.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  components: {
    BillingAccountDetails,
    SprintfWithLinks,
    Step,
    GlAlert,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
  },
  directives: {
    autofocusonshow,
  },
  mixins: [Tracking.mixin(), glFeatureFlagsMixin()],
  data() {
    return {
      billingAccount: null,
    };
  },
  apollo: {
    billingAccount: {
      query: getBillingAccountQuery,
      client: CUSTOMERSDOT_CLIENT,
      error(error) {
        this.handleError(error);
      },
    },
  },
  computed: {
    ...mapState([
      'country',
      'streetAddressLine1',
      'streetAddressLine2',
      'city',
      'countryState',
      'zipCode',
      'countryOptions',
      'stateOptions',
    ]),
    countryModel: {
      get() {
        return this.country;
      },
      set(country) {
        this.updateCountry(country);
      },
    },
    streetAddressLine1Model: {
      get() {
        return this.streetAddressLine1;
      },
      set(streetAddressLine1) {
        this.updateStreetAddressLine1(streetAddressLine1);
      },
    },
    streetAddressLine2Model: {
      get() {
        return this.streetAddressLine2;
      },
      set(streetAddressLine2) {
        this.updateStreetAddressLine2(streetAddressLine2);
      },
    },
    cityModel: {
      get() {
        return this.city;
      },
      set(city) {
        this.updateCity(city);
      },
    },
    countryStateModel: {
      get() {
        return this.countryState;
      },
      set(countryState) {
        this.updateCountryState(countryState);
      },
    },
    zipCodeModel: {
      get() {
        return this.zipCode;
      },
      set(zipCode) {
        this.updateZipCode(zipCode);
      },
    },
    isStateRequired() {
      return COUNTRIES_WITH_STATES_REQUIRED.includes(this.country);
    },
    isStateValid() {
      return this.isStateRequired ? !isEmpty(this.countryState) : true;
    },
    areRequiredFieldsValid() {
      return (
        !isEmpty(this.country) &&
        !isEmpty(this.streetAddressLine1) &&
        !isEmpty(this.city) &&
        !isEmpty(this.zipCode)
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
          text: COUNTRY_SELECT_PROMPT,
          value: null,
        },
        ...this.countryOptions,
      ];
    },
    stateOptionsWithDefault() {
      return [
        {
          text: STATE_SELECT_PROMPT,
          value: null,
        },
        ...this.stateOptions,
      ];
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
  },
  mounted() {
    this.fetchCountries();
  },
  methods: {
    ...mapActions([
      'fetchCountries',
      'fetchStates',
      'updateCountry',
      'updateStreetAddressLine1',
      'updateStreetAddressLine2',
      'updateCity',
      'updateCountryState',
      'updateZipCode',
    ]),
    trackStepTransition() {
      this.track('click_button', { label: 'select_country', property: this.country });
      this.track('click_button', { label: 'state', property: this.countryState });
      this.track('click_button', {
        label: 'saas_checkout_postal_code',
        property: this.zipCode,
      });
      this.track('click_button', { label: 'continue_payment' });
    },
    trackStepEdit() {
      this.track('click_button', {
        label: 'edit',
        property: STEP_BILLING_ADDRESS,
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
  stepId: STEP_BILLING_ADDRESS,
  billingAccountsUrl: gon.billing_accounts_url,
};
</script>
<template>
  <step
    :step-id="$options.stepId"
    :title="stepTitle"
    :is-valid="isValid"
    :next-step-button-text="$options.i18n.nextStepButtonText"
    @nextStep="trackStepTransition"
    @stepEdit="trackStepEdit"
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
        <gl-form-group :label="$options.i18n.countryLabel" label-size="sm" class="gl-mb-3">
          <gl-form-select
            v-model="countryModel"
            v-autofocusonshow
            :options="countryOptionsWithDefault"
            class="js-country"
            data-testid="country"
            @change="fetchStates"
          />
        </gl-form-group>
        <gl-form-group :label="$options.i18n.streetAddressLabel" label-size="sm" class="gl-mb-3">
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
        <gl-form-group :label="$options.i18n.cityLabel" label-size="sm" class="gl-mb-3">
          <gl-form-input v-model="cityModel" type="text" data-testid="city" />
        </gl-form-group>
        <div class="combined gl-display-flex">
          <gl-form-group :label="$options.i18n.stateLabel" label-size="sm" class="mr-3 w-50">
            <gl-form-select
              v-model="countryStateModel"
              :options="stateOptionsWithDefault"
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
        <div class="js-summary-line-1">{{ streetAddressLine1 }}</div>
        <div class="js-summary-line-2">{{ streetAddressLine2 }}</div>
        <div class="js-summary-line-3">{{ city }}, {{ countryState }} {{ zipCode }}</div>
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
