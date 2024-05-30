<script>
import { GlModal } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';

export default {
  name: 'SecretPreviewModal',
  components: {
    GlModal,
  },
  props: {
    createdAt: {
      type: Number,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    environment: {
      type: String,
      required: false,
      default: '',
    },
    expiration: {
      type: Date,
      required: false,
      default: undefined,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    isVisible: {
      type: Boolean,
      required: true,
    },
    rotationPeriod: {
      type: String,
      required: false,
      default: '',
    },
    secretKey: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    formattedCreatedAt() {
      return localeDateFormat.asDateTimeFull.format(this.createdAt);
    },
    formattedExpiration() {
      if (!this.expiration) {
        return __('None');
      }

      return localeDateFormat.asDateTimeFull.format(this.expiration);
    },
    actionPrimaryAttributes() {
      return {
        text: this.isEditing ? __('Save changes') : s__('Secrets|Add secret'),
        attributes: {
          variant: 'confirm',
        },
      };
    },
    title() {
      return sprintf(s__('Secrets|Preview for %{secretKey}'), { secretKey: this.secretKey }, false);
    },
  },
  actionSecondary: {
    text: __('Go back to edit'),
    attributes: {
      variant: 'default',
    },
  },
};
</script>
<template>
  <gl-modal
    modal-id="ci-secret-preview-modal"
    :visible="isVisible"
    :title="title"
    :action-primary="actionPrimaryAttributes"
    :action-cancel="$options.actionSecondary"
    size="sm"
    @primary="$emit('submit-secret')"
    @canceled="$emit('hide-preview-modal')"
    @change="$emit('hide-preview-modal')"
  >
    <p class="gl-font-bold">{{ __('Created on') }}</p>
    <p data-testid="secret-preview-created-at">{{ formattedCreatedAt }}</p>
    <p class="gl-font-bold">{{ __('Description') }}</p>
    <p data-testid="secret-preview-description">{{ description }}</p>
    <p class="gl-font-bold">{{ __('Environment') }}</p>
    <p data-testid="secret-preview-environment">{{ environment }}</p>
    <p class="gl-font-bold">{{ __('Expiration date') }}</p>
    <p data-testid="secret-preview-expiration">{{ formattedExpiration }}</p>
    <p class="gl-font-bold">{{ __('Rotation schedule') }}</p>
    <p data-testid="secret-preview-rotation-period">{{ rotationPeriod }}</p>
  </gl-modal>
</template>
