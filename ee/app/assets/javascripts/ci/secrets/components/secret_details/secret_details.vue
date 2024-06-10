<script>
import { __ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertRotationPeriod } from '../../utils';

export default {
  name: 'SecretDetails',
  props: {
    secret: {
      type: Object,
      required: true,
    },
  },
  computed: {
    createdAtText() {
      return localeDateFormat.asDateTimeFull.format(this.secret.createdAt);
    },
    descriptionText() {
      return this.secret.description || __('None');
    },
    expirationText() {
      return localeDateFormat.asDateTimeFull.format(this.secret.expiration);
    },
    rotationPeriodText() {
      return convertRotationPeriod(this.secret.rotationPeriod) || __('None');
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-4 gl-mt-4">
    <div>
      <h2 class="gl-heading-5">{{ __('Key') }}</h2>
      <p data-testid="secret-details-key">{{ secret.key }}</p>
    </div>
    <div>
      <h2 class="gl-heading-5">{{ __('Created on') }}</h2>
      <p data-testid="secret-details-created-at">{{ createdAtText }}</p>
    </div>
    <div>
      <h2 class="gl-heading-5">{{ __('Description') }}</h2>
      <p
        data-testid="secret-details-description"
        :class="{ 'gl-text-gray-500': !secret.description }"
      >
        {{ descriptionText }}
      </p>
    </div>
    <div>
      <h2 class="gl-heading-5">{{ __('Expiration date') }}</h2>
      <p data-testid="secret-details-expiration">{{ expirationText }}</p>
    </div>
    <div>
      <h2 class="gl-heading-5">{{ __('Rotation schedule') }}</h2>
      <p
        data-testid="secret-details-rotation-period"
        :class="{ 'gl-text-gray-500': !secret.rotationPeriod }"
      >
        {{ rotationPeriodText }}
      </p>
    </div>
  </div>
</template>
