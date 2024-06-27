<script>
import {
  GlForm,
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import CountryOrRegionSelector from 'jh_else_ee/trials/components/country_or_region_selector.vue';
import csrf from '~/lib/utils/csrf';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { trackSaasTrialSubmit } from 'ee/google_tag_manager';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COMPANY_SIZE_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
  companySizes,
} from 'ee/vue_shared/leads/constants';
import {
  TRIAL_COMPANY_SIZE_PROMPT,
  GENERIC_TRIAL_FORM_SUBMIT_TEXT,
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
  ULTIMATE_TRIAL_FORM_SUBMIT_TEXT,
  DUO_PRO_TRIAL_VARIANT,
} from '../constants';

export default {
  name: 'TrialCreateLeadForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    CountryOrRegionSelector,
    GlSprintf,
    GlLink,
  },
  directives: {
    autofocusonshow,
  },
  inject: ['user', 'submitPath', 'gtmSubmitEventLabel', 'trialVariant'],
  data() {
    return this.user;
  },
  computed: {
    companySizeOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.companySizeSelectPrompt,
          id: null,
        },
        ...companySizes,
      ];
    },
    submitBtnText() {
      if (this.trialVariant === DUO_PRO_TRIAL_VARIANT) {
        return this.$options.i18n.formSubmitText;
      }

      return this.$options.i18n.ultimateTrialFormSubmitText;
    },
  },
  methods: {
    onSubmit() {
      trackSaasTrialSubmit(this.gtmSubmitEventLabel);
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    companySizeLabel: LEADS_COMPANY_SIZE_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    ultimateTrialFormSubmitText: ULTIMATE_TRIAL_FORM_SUBMIT_TEXT,
    formSubmitText: GENERIC_TRIAL_FORM_SUBMIT_TEXT,
    companySizeSelectPrompt: TRIAL_COMPANY_SIZE_PROMPT,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    termsText: TRIAL_TERMS_TEXT,
    gitlabSubscription: TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
    privacyStatement: TRIAL_PRIVACY_STATEMENT,
    cookiePolicy: TRIAL_COOKIE_POLICY,
  },
};
</script>

<template>
  <gl-form :action="submitPath" method="post" @submit="onSubmit">
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <div class="gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row gl-mt-5">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first_name"
        class="gl-mr-5 gl-w-full gl-sm-w-half"
      >
        <gl-form-input
          id="first_name"
          :value="firstName"
          name="first_name"
          data-testid="first-name-field"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last_name"
        class="gl-w-full gl-sm-w-half"
      >
        <gl-form-input
          id="last_name"
          :value="lastName"
          name="last_name"
          data-testid="last-name-field"
          required
        />
      </gl-form-group>
    </div>
    <gl-form-group :label="$options.i18n.companyNameLabel" label-size="sm" label-for="company_name">
      <gl-form-input
        id="company_name"
        :value="companyName"
        name="company_name"
        data-testid="company-name-field"
        required
      />
    </gl-form-group>
    <gl-form-group :label="$options.i18n.companySizeLabel" label-size="sm" label-for="company_size">
      <gl-form-select
        id="company_size"
        :value="companySize"
        name="company_size"
        :options="companySizeOptionsWithDefault"
        value-field="id"
        text-field="name"
        data-testid="company-size-dropdown"
        required
      />
    </gl-form-group>
    <country-or-region-selector :country="country" :state="state" required />
    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      label-size="sm"
      :description="$options.i18n.phoneNumberDescription"
      label-for="phone_number"
    >
      <gl-form-input
        id="phone_number"
        :value="phoneNumber"
        name="phone_number"
        type="tel"
        data-testid="phone-number-field"
        pattern="^(\+)*[0-9\-\s]+$"
        required
      />
    </gl-form-group>
    <gl-button type="submit" variant="confirm" data-testid="continue-button" class="gl-w-full">
      {{ submitBtnText }}
    </gl-button>

    <div class="gl-mt-4">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #gitlabSubscriptionAgreement>
          <gl-link :href="$options.i18n.gitlabSubscription.url" target="_blank">
            {{ $options.i18n.gitlabSubscription.text }}
          </gl-link>
        </template>
        <template #privacyStatement>
          <gl-link :href="$options.i18n.privacyStatement.url" target="_blank">
            {{ $options.i18n.privacyStatement.text }}
          </gl-link>
        </template>
        <template #cookiePolicy>
          <gl-link :href="$options.i18n.cookiePolicy.url" target="_blank">
            {{ $options.i18n.cookiePolicy.text }}
          </gl-link>
        </template>
      </gl-sprintf>
    </div>
  </gl-form>
</template>
