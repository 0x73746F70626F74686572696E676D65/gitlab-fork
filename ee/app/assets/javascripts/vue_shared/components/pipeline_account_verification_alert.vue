<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: { GlAlert },
  i18n: {
    title: s__(
      'IdentityVerification|Before you can run pipelines, we need to verify your account.',
    ),
    description: s__(
      `IdentityVerification|We won't ask you for this information again. It will never be used for marketing purposes.`,
    ),
    buttonText: s__('IdentityVerification|Verify my account'),
  },
  inject: ['identityVerificationPath'],
  data() {
    return {
      isVisible: true,
    };
  },
  methods: {
    dismissAlert() {
      this.isVisible = false;
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="isVisible"
    :title="$options.i18n.title"
    :primary-button-text="$options.i18n.buttonText"
    :primary-button-link="identityVerificationPath"
    variant="danger"
    @dismiss="dismissAlert"
  >
    {{ $options.i18n.description }}
  </gl-alert>
</template>
