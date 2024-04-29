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
    };
  },
  watch: {
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
      const arkoseToken = response.token;

      this.$emit('challenge-solved', arkoseToken);
    },
    resetArkoseSession() {
      this.arkoseObject?.reset();
    },
  },
};
</script>

<template>
  <div
    v-show="arkoseLabsIframeShown"
    class="gl-display-flex gl-justify-content-center"
    :class="arkoseLabsContainerClass"
    data-testid="arkose-labs-challenge"
  ></div>
</template>
