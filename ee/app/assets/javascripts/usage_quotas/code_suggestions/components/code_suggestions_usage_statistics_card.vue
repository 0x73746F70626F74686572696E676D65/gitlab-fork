<script>
import { GlCard } from '@gitlab/ui';
import { s__ } from '~/locale';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  codeSuggestionsLearnMoreLink,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';

export default {
  name: 'CodeSuggestionsUsageStatisticsCard',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    codeSuggestionsAssignedInfoText: s__('CodeSuggestions|%{title} seats used'),
    codeSuggestionsIntroDescriptionText: s__(
      `CodeSuggestions|A user can be assigned a %{title} seat only once each billable month.`,
    ),
  },
  components: {
    GlCard,
    UsageStatistics,
  },
  props: {
    usageValue: {
      type: Number,
      required: true,
    },
    totalValue: {
      type: Number,
      required: true,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (val) => [DUO_PRO, DUO_ENTERPRISE].includes(val),
    },
  },
  computed: {
    percentage() {
      return Math.round((this.usageValue / this.totalValue) * 100);
    },
    shouldShowUsageStatistics() {
      return Boolean(this.totalValue) && this.percentage >= 0;
    },
    duoTitle() {
      return this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE;
    },
  },
};
</script>
<template>
  <gl-card v-if="shouldShowUsageStatistics" class="gl-p-3">
    <usage-statistics
      :percentage="percentage"
      :total-value="`${totalValue}`"
      :usage-value="`${usageValue}`"
    >
      <template #description>
        <p class="gl-font-sm gl-font-bold gl-mb-0" data-testid="code-suggestions-info">
          {{ sprintf($options.i18n.codeSuggestionsAssignedInfoText, { title: duoTitle }) }}
        </p>
      </template>
      <template #additional-info>
        <p class="gl-font-sm gl-mt-5" data-testid="code-suggestions-description">
          {{ sprintf($options.i18n.codeSuggestionsIntroDescriptionText, { title: duoTitle }) }}
        </p>
      </template>
    </usage-statistics>
  </gl-card>
</template>
