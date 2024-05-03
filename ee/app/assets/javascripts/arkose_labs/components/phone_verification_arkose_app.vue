<script>
import { uniqueId } from 'lodash';
import { logError } from '~/lib/logger';
import { initArkoseLabsChallenge } from '../init_arkose_labs';
import { CHALLENGE_CONTAINER_CLASS } from '../constants';

export default {
  name: 'PhoneVerificationArkoseApp',
  props: {
    publicKey: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
    },
    resetSession: {
      type: Boolean,
      required: false,
      default: false,
    },
    dataExchangePayload: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  data() {
    return {
      arkoseLabsIframeShown: false,
      arkoseLabsContainerClass: uniqueId(CHALLENGE_CONTAINER_CLASS),
      arkoseObject: null,
      arkoseToken: '',
    };
  },
  watch: {
    arkoseToken(token) {
      this.$emit('challenge-solved', token);
    },
    resetSession: {
      immediate: true,
      handler(reset) {
        if (reset) {
          this.resetArkoseSession();
        }
      },
    },
  },
  async mounted() {
    try {
      this.arkoseObject = await initArkoseLabsChallenge({
        publicKey: this.publicKey,
        domain: this.domain,
        dataExchangePayload: this.dataExchangePayload,
        config: {
          selector: `.${this.arkoseLabsContainerClass}`,
          onShown: this.onArkoseLabsIframeShown,
          onCompleted: this.passArkoseLabsChallenge,
        },
      });
    } catch (error) {
      logError('ArkoseLabs initialization error', error);
    }
  },
  methods: {
    onArkoseLabsIframeShown() {
      this.arkoseLabsIframeShown = true;
    },
    passArkoseLabsChallenge(response) {
      this.arkoseToken = response.token;
    },
    resetArkoseSession() {
      this.arkoseObject?.reset();
    },
  },
};
</script>

<template>
  <div>
    <!-- We use a hidden input here to simulate 'user solved the challenge' and
    trigger `challenge-solved` event in feature tests. See
    https://gitlab.com/gitlab-org/gitlab/-/issues/459947 -->
    <input v-model="arkoseToken" type="hidden" data-testid="arkose-labs-token-input" />

    <div
      v-show="arkoseLabsIframeShown"
      class="gl-display-flex gl-justify-content-center"
      :class="arkoseLabsContainerClass"
      data-testid="arkose-labs-challenge"
    ></div>
  </div>
</template>
