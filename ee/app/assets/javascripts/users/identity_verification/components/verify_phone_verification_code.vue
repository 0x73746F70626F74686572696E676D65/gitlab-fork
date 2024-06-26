<script>
import { GlForm, GlFormGroup, GlFormInput, GlIcon, GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import GlCountdown from '~/vue_shared/components/gl_countdown.vue';
import { s__, sprintf } from '~/locale';

import { createAlert, VARIANT_SUCCESS } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { validateVerificationCode } from '../validations';
import { UNKNOWN_TELESIGN_ERROR } from '../constants';

export default {
  name: 'VerifyPhoneVerificationCode',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlSprintf,
    GlLink,
    GlButton,
    GlCountdown,
  },
  i18n: {
    verificationCode: s__('IdentityVerification|Verification code'),
    description: s__("IdentityVerification|We've sent a verification code to +%{phoneNumber}"),
    noCode: s__(
      "IdentityVerification|Didn't receive a code? %{codeLinkStart}Send a new code%{codeLinkEnd} or %{phoneLinkStart}enter a new phone number%{phoneLinkEnd}",
    ),
    resendCodeIn: s__(
      "IdentityVerification|Didn't receive a code? Send a new code in %{timer} or %{phoneLinkStart}enter a new phone number%{phoneLinkEnd}",
    ),
    resendSuccess: s__('IdentityVerification|We sent a new code to +%{phoneNumber}'),
    verifyButton: s__('IdentityVerification|Verify phone number'),
  },
  inject: ['phoneSendCodePath', 'phoneVerifyCodePath', 'phoneNumber'],
  props: {
    latestPhoneNumber: {
      type: Object,
      required: false,
      default: () => {},
    },
    disableSubmitButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    additionalRequestParams: {
      type: Object,
      required: false,
      default: () => {},
    },
    sendCodeAllowed: {
      type: Boolean,
      required: true,
    },
    sendCodeAllowedAfter: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      form: {
        fields: {
          verificationCode: { value: '', state: null, feedback: '' },
        },
      },
      isLoading: false,
      alert: null,
    };
  },
  computed: {
    labelDescription() {
      return sprintf(this.$options.i18n.description, {
        phoneNumber: this.internationalPhoneNumber,
      });
    },
    internationalPhoneNumber() {
      return `${this.latestPhoneNumber.internationalDialCode}${this.latestPhoneNumber.number}`;
    },
    isSubmitButtonDisabled() {
      return this.disableSubmitButton || !this.form.fields.verificationCode.state;
    },
  },
  methods: {
    checkVerificationCode() {
      const errorMessage = validateVerificationCode(this.form.fields.verificationCode.value);
      this.form.fields.verificationCode.feedback = errorMessage;
      this.form.fields.verificationCode.state = errorMessage.length <= 0;
    },
    verifyCode() {
      this.isLoading = true;
      this.alert?.dismiss();

      axios
        .post(this.phoneVerifyCodePath, {
          verification_code: this.form.fields.verificationCode.value,
          ...this.additionalRequestParams,
        })
        .then(this.handleVerifySuccessResponse)
        .catch(this.handleError)
        .finally(() => {
          this.isLoading = false;
        });
    },
    handleVerifySuccessResponse() {
      this.$emit('verified');
    },
    resendCode() {
      this.isLoading = true;
      this.alert?.dismiss();

      axios
        .post(this.phoneSendCodePath, {
          country: this.latestPhoneNumber.country,
          international_dial_code: this.latestPhoneNumber.internationalDialCode,
          phone_number: this.latestPhoneNumber.number,
          ...this.additionalRequestParams,
        })
        .then(this.handleResendCodeResponse)
        .catch(this.handleError)
        .finally(() => {
          this.isLoading = false;
        });
    },
    handleResendCodeResponse({ data }) {
      this.$emit('verification-attempt');
      this.$emit('resent', data?.send_allowed_after);

      this.alert = createAlert({
        message: sprintf(this.$options.i18n.resendSuccess, {
          phoneNumber: this.internationalPhoneNumber,
        }),
        variant: VARIANT_SUCCESS,
      });
    },
    handleError(error) {
      if (error.response?.data?.reason === UNKNOWN_TELESIGN_ERROR) {
        this.$emit('verified');
        return;
      }

      this.$emit('verification-attempt');

      this.alert = createAlert({
        message: error.response?.data?.message || this.$options.i18n.I18N_GENERIC_ERROR,
        captureError: true,
        error,
      });
    },
    goBack() {
      this.resetForm();
      this.$emit('verification-attempt');
      this.$emit('back');
    },
    resetForm() {
      this.form.fields.verificationCode = { value: '', state: null, feedback: '' };
    },
    onTimerExpired() {
      this.$emit('timer-expired');
    },
  },
};
</script>
<template>
  <gl-form @submit.prevent="verifyCode">
    <gl-form-group
      :label="$options.i18n.verificationCode"
      :label-description="labelDescription"
      label-for="verification_code"
      :state="form.fields.verificationCode.state"
      :invalid-feedback="form.fields.verificationCode.feedback"
      data-testid="verification-code-form-group"
      class="gl-mb-2"
    >
      <gl-form-input
        v-model="form.fields.verificationCode.value"
        type="number"
        name="verification_code"
        :state="form.fields.verificationCode.state"
        trim
        autocomplete="one-time-code"
        data-testid="verification-code-form-input"
        class="gl-no-spin"
        @input="checkVerificationCode"
      />
    </gl-form-group>

    <div v-if="!disableSubmitButton" class="gl-font-sm gl-text-secondary">
      <gl-icon name="information-o" :size="12" class="gl-mt-2" />
      <gl-sprintf v-if="sendCodeAllowed" :message="$options.i18n.noCode">
        <template #codeLink="{ content }">
          <gl-link data-testid="resend-code-link" @click="resendCode">{{ content }}</gl-link>
        </template>
        <template #phoneLink="{ content }">
          <gl-link @click="goBack">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
      <gl-sprintf v-else :message="$options.i18n.resendCodeIn">
        <template #timer>
          <gl-countdown :end-date-string="sendCodeAllowedAfter" @timer-expired="onTimerExpired" />
        </template>
        <template #phoneLink="{ content }">
          <gl-link @click="goBack">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>

    <slot name="captcha"></slot>

    <gl-button
      type="submit"
      variant="confirm"
      class="!gl-w-full gl-mt-5"
      :disabled="isSubmitButtonDisabled"
      :loading="isLoading"
    >
      {{ $options.i18n.verifyButton }}
    </gl-button>
  </gl-form>
</template>
