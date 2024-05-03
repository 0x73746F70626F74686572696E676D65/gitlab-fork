<script>
import { GlIcon, GlLink, GlCard } from '@gitlab/ui';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import { sprintf, s__ } from '~/locale';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import {
  STORAGE_STATISTICS_PURCHASED_STORAGE,
  STORAGE_STATISTICS_TOTAL_STORAGE,
  STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
} from '../constants';

/**
 * NamespaceLimitsTotalStorageAvailableBreakdownCard
 *
 * This card is used on Namespace Usage Quotas
 * when the namespace has Namespace-level storage limits
 * https://docs.gitlab.com/ee/user/usage_quotas#namespace-storage-limit
 * It breaks down the storage available: included in the plan & purchased storage
 */

export default {
  name: 'NamespaceLimitsTotalStorageAvailableBreakdownCard',
  components: { GlIcon, GlLink, GlCard, NumberToHumanSize },
  inject: ['namespacePlanName', 'namespaceStorageLimit'],
  props: {
    purchasedStorage: {
      type: Number,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    planStorageDescription() {
      return sprintf(s__('UsageQuota|Included in %{planName} subscription'), {
        planName: this.namespacePlanName,
      });
    },
    totalStorageAvailable() {
      return this.namespaceStorageLimit + this.purchasedStorage;
    },
  },
  i18n: {
    PURCHASED_USAGE_HELP_LINK: usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit,
    STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
    STORAGE_STATISTICS_PURCHASED_STORAGE,
    STORAGE_STATISTICS_TOTAL_STORAGE,
  },
};
</script>

<template>
  <gl-card data-testid="storage-detail-card">
    <div
      class="gl-display-flex gl-justify-content-space-between gl-gap-5"
      data-testid="storage-included-in-plan"
    >
      <div class="gl-w-80p">{{ planStorageDescription }}</div>
      <div v-if="loading" class="gl-animate-skeleton-loader gl-w-8 gl-h-5 gl-rounded-base"></div>
      <number-to-human-size v-else class="gl-whitespace-nowrap" :value="namespaceStorageLimit" />
    </div>
    <div class="gl-display-flex gl-justify-content-space-between">
      <div class="gl-w-80p">
        {{ $options.i18n.STORAGE_STATISTICS_PURCHASED_STORAGE }}
        <gl-link
          :href="$options.i18n.PURCHASED_USAGE_HELP_LINK"
          target="_blank"
          class="gl-ml-2"
          :aria-label="$options.i18n.STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE"
        >
          <gl-icon name="question-o" />
        </gl-link>
      </div>
      <div v-if="loading" class="gl-animate-skeleton-loader gl-w-8 gl-h-5 gl-rounded-base"></div>
      <number-to-human-size
        v-else
        class="gl-whitespace-nowrap"
        :value="purchasedStorage"
        data-testid="storage-purchased"
      />
    </div>
    <hr />
    <div class="gl-display-flex gl-justify-content-space-between">
      <div class="gl-w-80p">{{ $options.i18n.STORAGE_STATISTICS_TOTAL_STORAGE }}</div>
      <div v-if="loading" class="gl-animate-skeleton-loader gl-w-8 gl-h-5 gl-rounded-base"></div>
      <number-to-human-size
        v-else
        class="gl-whitespace-nowrap"
        :value="totalStorageAvailable"
        data-testid="total-storage"
      />
    </div>
  </gl-card>
</template>
