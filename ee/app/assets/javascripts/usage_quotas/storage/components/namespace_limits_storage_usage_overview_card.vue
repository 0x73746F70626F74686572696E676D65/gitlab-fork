<script>
import { GlCard, GlProgressBar, GlIcon, GlLink } from '@gitlab/ui';
import { sprintf } from '~/locale';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import {
  STORAGE_STATISTICS_PERCENTAGE_REMAINING,
  STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
} from '../constants';

export default {
  name: 'NamespaceLimitsStorageUsageOverviewCard',
  components: {
    GlCard,
    GlProgressBar,
    GlIcon,
    GlLink,
    NumberToHumanSize,
  },
  inject: ['namespaceStorageLimit'],
  props: {
    purchasedStorage: {
      type: Number,
      required: false,
      default: 0,
    },
    usedStorage: {
      type: Number,
      required: false,
      default: 0,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    totalStorageAvailable() {
      return this.namespaceStorageLimit + this.purchasedStorage;
    },
    percentageUsed() {
      // don't show the progress bar if there's no total storage
      if (!this.totalStorageAvailable) {
        return null;
      }

      const usedRatio = Math.max(
        Math.round((this.usedStorage / this.totalStorageAvailable) * 100),
        0,
      );

      return Math.min(usedRatio, 100);
    },
    percentageRemaining() {
      if (this.percentageUsed === null) {
        return null;
      }

      const percentageRemaining = Math.max(100 - this.percentageUsed, 0);

      return sprintf(STORAGE_STATISTICS_PERCENTAGE_REMAINING, {
        percentageRemaining,
      });
    },
  },
  i18n: {
    STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
  },
  usageQuotasHelpPaths,
};
</script>

<template>
  <gl-card>
    <div class="gl-font-weight-bold" data-testid="namespace-storage-card-title">
      {{ s__('UsageQuota|Namespace storage used') }}

      <gl-link
        :href="$options.usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit"
        target="_blank"
        class="gl-ml-2"
        :aria-label="$options.i18n.STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE"
      >
        <gl-icon name="question-o" />
      </gl-link>
    </div>

    <div
      v-if="loading"
      class="gl-animate-skeleton-loader gl-max-w-26 gl-h-7 gl-rounded-base gl-my-3"
    ></div>
    <div v-else class="gl-font-size-h-display gl-font-weight-bold gl-leading-1 gl-my-3">
      <number-to-human-size label-class="gl-font-lg" :value="usedStorage" plain-zero />
      <template v-if="totalStorageAvailable">
        /
        <number-to-human-size label-class="gl-font-lg" :value="totalStorageAvailable" plain-zero />
      </template>
    </div>

    <template v-if="percentageUsed !== null">
      <div
        v-if="loading"
        class="gl-animate-skeleton-loader gl-h-2 gl-max-w-none! gl-rounded-base gl-mb-4"
      ></div>
      <gl-progress-bar v-else :value="percentageUsed" class="gl-my-4" />

      <div
        v-if="loading"
        class="gl-animate-skeleton-loader gl-max-w-26 gl-h-5 gl-rounded-base gl-my-3"
      ></div>
      <div v-else data-testid="namespace-storage-percentage-remaining">
        {{ percentageRemaining }}
      </div>
    </template>
  </gl-card>
</template>
