<script>
import { GlButton } from '@gitlab/ui';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { s__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import { EXPLORE_PAID_PLANS_CLICKED } from 'ee/usage_quotas/seats/constants';

export default {
  name: 'PublicNamespacePlanInfoCard',
  components: {
    GlButton,
    UsageStatistics,
  },
  mixins: [Tracking.mixin()],
  inject: ['explorePlansPath', 'namespaceId'],
  data() {
    return {
      plan: {},
    };
  },
  apollo: {
    plan: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.parsedNamespaceId,
        };
      },
      update: (data) => ({
        code: data?.subscription?.plan.code,
        name: data?.subscription?.plan.name,
      }),
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
    parsedNamespaceId() {
      return parseInt(this.namespaceId, 10);
    },
    planName() {
      return this.plan.name || capitalizeFirstCharacter(this.plan.code);
    },
    shouldShowExplorePaidPlansButton() {
      return !this.isLoading;
    },
    title() {
      return sprintf(this.$options.i18n.planText, { plan: this.planName });
    },
  },
  methods: {
    handleExplorePlans() {
      this.track('click_button', { label: EXPLORE_PAID_PLANS_CLICKED });
    },
  },
  i18n: {
    explorePlansText: s__('Billing|Explore paid plans'),
    freePlanInfoText: s__('Billing|You can upgrade to a paid tier to get access to more features.'),
    planText: s__('Billing|%{plan} Plan'),
  },
};
</script>
<template>
  <div class="gl-bg-white gl-border-1 gl-border-gray-100 gl-border-solid gl-p-6 gl-rounded-base">
    <usage-statistics>
      <template #actions>
        <gl-button
          v-if="shouldShowExplorePaidPlansButton"
          :href="explorePlansPath"
          category="primary"
          target="_blank"
          size="small"
          variant="confirm"
          data-testid="explore-plans"
          @click="handleExplorePlans"
        >
          {{ $options.i18n.explorePlansText }}
        </gl-button>
      </template>
      <template #description>
        <p class="gl-font-size-h2 gl-font-bold" data-testid="title">{{ title }}</p>
        <p data-testid="free-plan-info">
          {{ $options.i18n.freePlanInfoText }}
        </p>
      </template>
    </usage-statistics>
  </div>
</template>
