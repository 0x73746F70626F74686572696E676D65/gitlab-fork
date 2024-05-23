<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import Zuora from 'ee/billings/components/zuora_simple.vue';
import { I18N_GENERIC_ERROR, RELATED_TO_BANNED_USER } from '../constants';
import Captcha from './identity_verification_captcha.vue';

export const EVENT_CATEGORY = 'IdentityVerification::CreditCard';
export const EVENT_FAILED = 'failed_attempt';
export const EVENT_SUCCESS = 'success';

export default {
  components: {
    GlButton,
    GlIcon,
    Zuora,
    Captcha,
  },
  mixins: [Tracking.mixin({ category: EVENT_CATEGORY })],
  inject: [
    'creditCardVerifyPath',
    'creditCardVerifyCaptchaPath',
    'creditCard',
    'offerPhoneNumberExemption',
  ],
  props: {
    requireChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      currentUserId: this.creditCard.userId,
      formId: this.creditCard.formId,
      hasLoadError: false,
      isFormLoading: true,
      errorMessage: undefined,
      isRelatedToBannedUser: false,
      disableSubmitButton: false,
      isLoading: false,
      verificationAttempts: 0,
      captchaData: {},
    };
  },
  computed: {
    loadingStyle() {
      return { height: `${this.$options.zuoraFormHeight}px` };
    },
    isSubmitButtonDisabled() {
      return (
        this.disableSubmitButton ||
        this.isFormLoading ||
        this.hasLoadError ||
        this.isRelatedToBannedUser
      );
    },
  },
  methods: {
    handleCheckForReuseResponse() {
      this.$emit('completed');
      this.track(EVENT_SUCCESS);
    },
    handleCheckForReuseError(error) {
      if (error.response.data?.message) {
        this.errorMessage = error.response.data.message;
        this.isRelatedToBannedUser = error.response.data?.reason === RELATED_TO_BANNED_USER;
      } else {
        createAlert({
          message: I18N_GENERIC_ERROR,
          captureError: true,
          error,
        });
      }
    },
    handleFormLoading(isFormLoading) {
      this.isFormLoading = isFormLoading;

      if (!isFormLoading && this.errorMessage) {
        this.alert = createAlert({ message: this.errorMessage });
        this.errorMessage = undefined;
      }
    },
    handleFormLoadError() {
      this.hasLoadError = true;
    },
    handleValidationError({ message }) {
      this.track(EVENT_FAILED, { property: message });
    },
    handleValidationSuccess() {
      this.isLoading = true;

      axios
        .get(this.creditCardVerifyPath)
        .then(this.handleCheckForReuseResponse)
        .catch(this.handleCheckForReuseError)
        .finally(() => {
          this.isLoading = false;
        });
    },
    increaseVerificationAttempts() {
      this.verificationAttempts += 1;
    },
    onCaptchaShown() {
      this.disableSubmitButton = true;
    },
    onCaptchaSolved(data) {
      this.disableSubmitButton = false;
      this.captchaData = data;
    },
    onCaptchaReset() {
      this.disableSubmitButton = true;
      this.captchaData = {};
    },
    submit() {
      if (this.requireChallenge) {
        this.isLoading = true;
        axios
          .post(this.creditCardVerifyCaptchaPath, this.captchaData)
          .then(() => {
            this.alert?.dismiss();
            this.$refs.zuora.submit();
          })
          .catch((error) => {
            createAlert({ message: error.response?.data?.message || I18N_GENERIC_ERROR });
          })
          .finally(() => {
            this.increaseVerificationAttempts();
            this.isLoading = false;
          });
      } else {
        this.alert?.dismiss();
        this.$refs.zuora.submit();
      }
    },
  },
  i18n: {
    formInfo: s__(
      'IdentityVerification|GitLab will not charge or store your payment information, it will only be used for verification.',
    ),
    formSubmit: s__('IdentityVerification|Verify payment method'),
    verifyWithPhone: s__('IdentityVerification|Verify with a phone number instead?'),
  },
  zuoraFormHeight: 328,
};
</script>
<template>
  <div class="gl-display-flex gl-flex-direction-column">
    <zuora
      ref="zuora"
      :current-user-id="currentUserId"
      :initial-height="$options.zuoraFormHeight"
      :payment-form-id="formId"
      @loading="handleFormLoading"
      @load-error="handleFormLoadError"
      @client-validation-error="handleValidationError"
      @server-validation-error="handleValidationError"
      @success="handleValidationSuccess"
    />

    <div class="gl-display-flex gl-mt-4 gl-mx-4 gl-text-secondary">
      <gl-icon class="gl-flex-shrink-0 gl-mt-2" name="information-o" :size="14" />
      <span class="gl-ml-2">{{ $options.i18n.formInfo }}</span>
    </div>

    <captcha
      :show-arkose-challenge="requireChallenge"
      :verification-attempts="verificationAttempts"
      @captcha-shown="onCaptchaShown"
      @captcha-solved="onCaptchaSolved"
      @captcha-reset="onCaptchaReset"
    />

    <gl-button
      class="gl-mt-6"
      variant="confirm"
      type="submit"
      :disabled="isSubmitButtonDisabled"
      :loading="isLoading"
      @click="submit"
    >
      {{ $options.i18n.formSubmit }}
    </gl-button>
    <gl-button
      v-if="offerPhoneNumberExemption"
      block
      variant="link"
      class="gl-mt-5 gl-font-sm"
      @click="$emit('exemptionRequested')"
      >{{ $options.i18n.verifyWithPhone }}</gl-button
    >
  </div>
</template>
