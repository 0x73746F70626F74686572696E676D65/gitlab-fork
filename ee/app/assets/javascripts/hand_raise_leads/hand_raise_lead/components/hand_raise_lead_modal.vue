<script>
import { GlFormGroup, GlFormInput, GlFormSelect, GlFormTextarea, GlModal } from '@gitlab/ui';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  companySizes,
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COMPANY_SIZE_LABEL,
  LEADS_COUNTRY_LABEL,
  LEADS_COUNTRY_PROMPT,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import {
  PQL_COMMENT_LABEL,
  PQL_COMPANY_SIZE_PROMPT,
  PQL_HAND_RAISE_ACTION_ERROR,
  PQL_HAND_RAISE_ACTION_SUCCESS,
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
  PQL_MODAL_CANCEL,
  PQL_MODAL_FOOTER_TEXT,
  PQL_MODAL_HEADER_TEXT,
  PQL_MODAL_PRIMARY,
  PQL_MODAL_TITLE,
  PQL_PHONE_DESCRIPTION,
  PQL_STATE_LABEL,
  PQL_STATE_PROMPT,
} from '../constants';
import eventHub from '../event_hub';

export default {
  name: 'HandRaiseLeadModal',
  components: {
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormTextarea,
    GlModal,
    CountryOrRegionSelector,
  },
  mixins: [Tracking.mixin()],
  props: {
    user: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    modalId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      firstName: this.user.firstName,
      lastName: this.user.lastName,
      companyName: this.user.companyName,
      companySize: null,
      phoneNumber: '',
      country: '',
      state: '',
      countries: [],
      states: [],
      comment: '',
      stateRequired: false,
      ctaTracking: {},
      glmContent: '',
      productInteraction: '',
    };
  },
  apollo: {
    countries: {
      query: countriesQuery,
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.country;
      },
      variables() {
        return {
          countryId: this.country,
        };
      },
    },
  },
  computed: {
    modalHeaderText() {
      return sprintf(this.$options.i18n.modalHeaderText, {
        userName: this.user.userName,
      });
    },
    canSubmit() {
      return (
        this.firstName &&
        this.lastName &&
        this.companyName &&
        this.companySize &&
        this.phoneNumber &&
        this.country &&
        (this.stateRequired ? this.state : true)
      );
    },
    actionPrimary() {
      return {
        text: this.$options.i18n.modalPrimary,
        attributes: { variant: 'confirm', disabled: !this.canSubmit },
      };
    },
    actionCancel() {
      return {
        text: this.$options.i18n.modalCancel,
      };
    },
    tracking() {
      return {
        label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
        experiment: this.ctaTracking.experiment,
      };
    },
    companySizeOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.companySizeSelectPrompt,
          id: null,
        },
        ...companySizes,
      ];
    },
    formParams() {
      return {
        namespaceId: Number(this.user.namespaceId),
        firstName: this.firstName,
        lastName: this.lastName,
        companyName: this.companyName,
        companySize: this.companySize,
        phoneNumber: this.phoneNumber,
        country: this.country,
        state: this.stateRequired ? this.state : null,
        comment: this.comment,
        glmContent: this.glmContent,
        productInteraction: this.productInteraction,
      };
    },
  },
  mounted() {
    eventHub.$on('openModal', (options) => {
      this.openModal(options);
    });
  },
  methods: {
    openModal({ productInteraction, ctaTracking, glmContent, modalIdToOpen }) {
      // The items being passed here are what can be unique about a particular
      // instance of this modal.
      this.productInteraction = productInteraction;
      this.ctaTracking = ctaTracking;
      this.glmContent = glmContent;

      // TODO: Since we are still potentially putting multiple modals into the DOM, we need to ensure
      // we only open the one we care about. In the next step of
      // https://gitlab.com/gitlab-org/gitlab/-/issues/443674 we will ensure only one
      // instance of the modal is loaded and we can remove this logic and passing
      // of modalId.
      if (modalIdToOpen !== this.modalId) {
        return;
      }

      this.$root.$emit(BV_SHOW_MODAL, this.modalId);
      this.track('hand_raise_form_viewed');
    },
    resetForm() {
      this.firstName = '';
      this.lastName = '';
      this.companyName = '';
      this.companySize = null;
      this.phoneNumber = '';
      this.country = '';
      this.state = '';
      this.comment = '';
      this.stateRequired = false;
    },
    async submit() {
      await SubscriptionsApi.sendHandRaiseLead(this.submitPath, this.formParams)
        .then(() => {
          createAlert({
            message: this.$options.i18n.handRaiseActionSuccess,
            variant: VARIANT_SUCCESS,
          });
          this.resetForm();
          this.track('hand_raise_submit_form_succeeded');
        })
        .catch((error) => {
          createAlert({
            message: this.$options.i18n.handRaiseActionError,
            captureError: true,
            error,
          });
          this.track('hand_raise_submit_form_failed');
        });
    },
    onChange({ country, state, stateRequired }) {
      this.country = country;
      this.state = state;
      this.stateRequired = stateRequired;
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    companySizeLabel: LEADS_COMPANY_SIZE_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    countryLabel: LEADS_COUNTRY_LABEL,
    countrySelectPrompt: LEADS_COUNTRY_PROMPT,
    companySizeSelectPrompt: PQL_COMPANY_SIZE_PROMPT,
    phoneNumberDescription: PQL_PHONE_DESCRIPTION,
    stateLabel: PQL_STATE_LABEL,
    stateSelectPrompt: PQL_STATE_PROMPT,
    commentLabel: PQL_COMMENT_LABEL,
    modalTitle: PQL_MODAL_TITLE,
    modalPrimary: PQL_MODAL_PRIMARY,
    modalCancel: PQL_MODAL_CANCEL,
    modalHeaderText: PQL_MODAL_HEADER_TEXT,
    modalFooterText: PQL_MODAL_FOOTER_TEXT,
    handRaiseActionError: PQL_HAND_RAISE_ACTION_ERROR,
    handRaiseActionSuccess: PQL_HAND_RAISE_ACTION_SUCCESS,
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
    data-testid="hand-raise-lead-modal"
    size="sm"
    :title="$options.i18n.modalTitle"
    :action-primary="actionPrimary"
    :action-cancel="actionCancel"
    @primary="submit"
    @cancel="track('hand_raise_form_canceled')"
  >
    {{ modalHeaderText }}
    <div class="combined gl-display-flex gl-mt-5">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first-name"
        class="mr-3 w-50"
      >
        <gl-form-input
          id="first-name"
          v-model="firstName"
          type="text"
          class="form-control"
          data-testid="first-name"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last-name"
        class="w-50"
      >
        <gl-form-input
          id="last-name"
          v-model="lastName"
          type="text"
          class="form-control"
          data-testid="last-name"
        />
      </gl-form-group>
    </div>
    <div class="combined gl-display-flex">
      <gl-form-group
        :label="$options.i18n.companyNameLabel"
        label-size="sm"
        label-for="company-name"
        class="mr-3 w-50"
      >
        <gl-form-input
          id="company-name"
          v-model="companyName"
          type="text"
          class="form-control"
          data-testid="company-name"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.companySizeLabel"
        label-size="sm"
        label-for="company-size"
        class="w-50"
      >
        <gl-form-select
          v-model="companySize"
          name="company-size"
          :options="companySizeOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="company-size"
        />
      </gl-form-group>
    </div>
    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      label-size="sm"
      :description="$options.i18n.phoneNumberDescription"
      label-for="phone-number"
    >
      <gl-form-input
        id="phone-number"
        v-model="phoneNumber"
        type="text"
        class="form-control"
        data-testid="phone-number"
      />
    </gl-form-group>
    <country-or-region-selector :country="country" :state="state" @change="onChange" />
    <gl-form-group :label="$options.i18n.commentLabel" label-size="sm" label-for="comment">
      <gl-form-textarea v-model="comment" no-resize />
    </gl-form-group>

    <p class="gl-text-gray-400">
      {{ $options.i18n.modalFooterText }}
    </p>
  </gl-modal>
</template>
