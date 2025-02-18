<script>
import {
  GlIcon,
  GlLink,
  GlCard,
  GlButton,
  GlProgressBar,
  GlModalDirective,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE, BUY_STORAGE } from '../constants';

/**
 * ProjectLimitsExcessStorageBreakdownCard
 *
 * This card is used on Namespace Usage Quotas
 * when the namespace has Project-level storage limits
 * https://docs.gitlab.com/ee/user/usage_quotas#project-storage-limit
 * It describes the relationship between excess storage and purchased storage
 */

export default {
  name: 'ProjectLimitsExcessStorageBreakdownCard',
  components: {
    GlIcon,
    GlLink,
    GlCard,
    GlButton,
    GlProgressBar,
    GlSkeletonLoader,
    NumberToHumanSize,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'purchaseStorageUrl',
    'buyAddonTargetAttr',
    'totalRepositorySizeExcess',
    'perProjectStorageLimit',
    'namespacePlanName',
  ],
  props: {
    loading: {
      type: Boolean,
      required: true,
    },
    purchasedStorage: {
      type: Number,
      required: true,
    },
    limitedAccessModeEnabled: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    showPercentageInfo() {
      return this.purchasedStorage && this.totalRepositorySizeExcess;
    },
    percentageUsed() {
      const usedRatio = Math.max(
        Math.round((this.totalRepositorySizeExcess / this.purchasedStorage) * 100),
        0,
      );
      return Math.min(usedRatio, 100);
    },
    percentageRemaining() {
      const percentageRemaining = Math.max(100 - this.percentageUsed, 0);

      return sprintf(s__('UsageQuota|%{percentageRemaining}%% purchased storage remaining.'), {
        percentageRemaining,
      });
    },
    planStorageDescription() {
      const projectEnforcementTypeTitle = s__(
        'UsageQuota|Storage per project included in %{planName} subscription',
      );

      return sprintf(projectEnforcementTypeTitle, {
        planName: this.namespacePlanName,
      });
    },
  },
  i18n: {
    PROJECT_ENFORCEMENT_PURCHASE_CARD_TITLE: s__('UsageQuota|Total excess storage'),
    STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
    PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE: s__(
      'UsageQuota|This namespace is under project-level limits, so only repository and LFS storage usage above the limit included in the plan is counted as excess storage. You can increase excess storage limit by purchasing storage packages.',
    ),
    BUY_STORAGE,
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
            :href="$options.usageQuotasHelpPaths.usageQuotasProjectStorageLimit"
            target="_blank"
            class="gl-ml-2"
            :aria-label="$options.i18n.STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE"
          >
            <gl-icon name="question-o" />
          </gl-link>
        </div>
        <template v-if="purchaseStorageUrl">
          <gl-button
            v-if="!limitedAccessModeEnabled"
            :href="purchaseStorageUrl"
            :target="buyAddonTargetAttr"
            category="primary"
            variant="confirm"
            data-testid="purchase-more-storage"
            class="gl-absolute gl-top-4 gl-right-4"
          >
            {{ $options.i18n.BUY_STORAGE }}
          </gl-button>
          <gl-button
            v-else
            v-gl-modal-directive="'limited-access-modal-id'"
            category="primary"
            variant="confirm"
            data-testid="purchase-more-storage"
            class="gl-absolute gl-top-4 gl-right-4"
          >
            {{ $options.i18n.BUY_STORAGE }}
          </gl-button>
        </template>
      </div>
      <div class="gl-font-size-h-display gl-font-bold gl-leading-1 gl-my-3">
        <number-to-human-size
          label-class="gl-font-lg"
          :value="Number(totalRepositorySizeExcess)"
          plain-zero
        />
        /
        <number-to-human-size
          label-class="gl-font-lg"
          :value="Number(purchasedStorage)"
          plain-zero
          data-testid="storage-purchased"
        />
      </div>
      <template v-if="showPercentageInfo">
        <gl-progress-bar :value="percentageUsed" class="gl-my-4" />
        <div data-testid="purchased-storage-percentage-remaining">
          {{ percentageRemaining }}
        </div>
      </template>
      <hr class="gl-my-4" />
      <p>{{ $options.i18n.PROJECT_ENFORCEMENT_PURCHASE_CARD_SUBTITLE }}</p>
      <p v-if="perProjectStorageLimit">
        <strong><number-to-human-size :value="perProjectStorageLimit" /></strong>

        {{ planStorageDescription }}
      </p>
    </div>
  </gl-card>
</template>
