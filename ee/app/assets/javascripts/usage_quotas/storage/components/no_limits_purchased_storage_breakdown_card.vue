<script>
import { GlIcon, GlLink, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE } from '../constants';

export default {
  name: 'NoLimitsPurchasedStorageBreakdownCard',
  components: {
    GlIcon,
    GlLink,
    GlCard,
    GlSkeletonLoader,
    NumberToHumanSize,
  },
  props: {
    loading: {
      type: Boolean,
      required: true,
    },
    purchasedStorage: {
      type: Number,
      required: true,
    },
  },
  i18n: {
    PROJECT_ENFORCEMENT_PURCHASE_CARD_TITLE: s__('UsageQuota|Purchased storage'),
    STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
    PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE: s__(
      'UsageQuota|Any additional purchased storage will be displayed here.',
    ),
  },
  usageQuotasHelpPaths,
};
</script>

<template>
  <gl-card>
    <gl-skeleton-loader v-if="loading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <div v-else>
      <div class="gl-display-flex gl-align-items-center gl-justify-content-space-between">
        <div class="gl-font-bold" data-testid="purchased-storage-card-title">
          {{ $options.i18n.PROJECT_ENFORCEMENT_PURCHASE_CARD_TITLE }}

          <gl-link
            :href="$options.usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit"
            target="_blank"
            class="gl-ml-2"
            :aria-label="$options.i18n.STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE"
          >
            <gl-icon name="question-o" />
          </gl-link>
        </div>
      </div>
      <div class="gl-font-size-h-display gl-font-bold gl-leading-1 gl-my-3">
        <number-to-human-size
          label-class="gl-font-lg"
          :value="Number(purchasedStorage)"
          plain-zero
          data-testid="storage-purchased"
        />
      </div>
      <hr class="gl-my-4" />
      <p>{{ $options.i18n.PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE }}</p>
    </div>
  </gl-card>
</template>
