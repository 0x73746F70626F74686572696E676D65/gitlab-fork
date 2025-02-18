<script>
import { VERIFICATION_TOKEN_INPUT_NAME } from 'ee/arkose_labs/constants';
import PhoneVerificationArkoseApp from 'ee/arkose_labs/components/phone_verification_arkose_app.vue';
import ReCaptcha from '~/captcha/captcha_modal.vue';

export default {
  name: 'IdentityVerificationCaptcha',
  components: {
    PhoneVerificationArkoseApp,
    ReCaptcha,
  },
  inject: ['arkoseConfiguration', 'arkoseDataExchangePayload'],
  props: {
    showArkoseChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRecaptchaChallenge: {
      type: Boolean,
      required: false,
      default: false,
    },
    verificationAttempts: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      arkose: { challengeSolved: false, token: '', reset: false },
      recaptcha: { challengeSolved: false, token: '', reset: false },
    };
  },
  computed: {
    renderCaptcha() {
      return this.showArkoseChallenge || this.showRecaptchaChallenge;
    },
    recaptchaSiteKey() {
      return gon.recaptcha_sitekey;
    },
  },
  watch: {
    verificationAttempts() {
      this.resetCaptcha();
    },
  },
  mounted() {
    if (this.renderCaptcha) {
      this.$emit('captcha-shown');
    }
  },
  methods: {
    onArkoseChallengeSolved(arkoseToken) {
      this.arkose = { challengeSolved: true, token: arkoseToken, reset: false };

      this.$emit('captcha-solved', { [VERIFICATION_TOKEN_INPUT_NAME]: arkoseToken });
    },
    onReCaptchaSolved(response) {
      this.recaptcha = { challengeSolved: true, token: response, reset: false };

      this.$emit('captcha-solved', { 'g-recaptcha-response': response });
    },
    resetCaptcha() {
      if (this.renderCaptcha) {
        this.arkose = { challengeSolved: false, token: '', reset: true };
        this.recaptcha = { challengeSolved: false, token: '', reset: true };

        this.$emit('captcha-reset');
      }
    },
  },
};
</script>
<template>
  <div>
    <div v-if="showRecaptchaChallenge" class="gl-text-center gl-mt-3">
      <re-captcha
        :captcha-site-key="recaptchaSiteKey"
        :show-modal="false"
        :reset-session="recaptcha.reset"
        needs-captcha-response
        @receivedCaptchaResponse="onReCaptchaSolved"
      />
    </div>

    <phone-verification-arkose-app
      v-if="showArkoseChallenge"
      :public-key="arkoseConfiguration.apiKey"
      :domain="arkoseConfiguration.domain"
      :data-exchange-payload="arkoseDataExchangePayload"
      :reset-session="arkose.reset"
      class="gl-mt-5"
      @challenge-solved="onArkoseChallengeSolved"
    />
  </div>
</template>
