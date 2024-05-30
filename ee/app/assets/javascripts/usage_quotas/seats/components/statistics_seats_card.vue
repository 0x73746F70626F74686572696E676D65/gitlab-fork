<script>
import { GlLink, GlIcon, GlButton, GlModalDirective, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import {
  addSeatsText,
  EXPLORE_PAID_PLANS_CLICKED,
  PLAN_CODE_FREE,
  seatsOwedHelpText,
  seatsOwedLink,
  seatsOwedText,
  seatsUsedHelpText,
  seatsUsedLink,
  seatsUsedText,
} from 'ee/usage_quotas/seats/constants';
import Tracking from '~/tracking';
import { visitUrl } from '~/lib/utils/url_utility';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';

export default {
  name: 'StatisticsSeatsCard',
  components: { GlLink, GlIcon, GlButton, LimitedAccessModal, GlSkeletonLoader },
  directives: {
    GlModalDirective,
  },
  helpLinks: {
    seatsUsedLink,
    seatsOwedLink,
  },
  i18n: {
    seatsUsedText,
    seatsUsedHelpText,
    seatsOwedText,
    seatsOwedHelpText,
    addSeatsText,
    explorePlansText: s__('Billing|Explore paid plans'),
  },
  mixins: [Tracking.mixin()],
  inject: ['explorePlansPath'],
  props: {
    seatsUsed: {
      type: Number,
      required: false,
      default: null,
    },
    seatsOwed: {
      type: Number,
      required: false,
      default: null,
    },
    purchaseButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    purchaseButtonText: {
      type: String,
      required: false,
      default: null,
    },
    namespaceId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      plan: {},
      subscriptionPermissions: null,
      showLimitedAccessModal: false,
    };
  },
  computed: {
    hasLimitedAccess() {
      return (
        gon.features?.limitedAccessModal && LIMITED_ACCESS_KEYS.includes(this.permissionReason)
      );
    },
    isFreePlan() {
      return this.plan.code === PLAN_CODE_FREE;
    },
    shouldRenderSeatsUsedBlock() {
      return this.seatsUsed !== null;
    },
    shouldRenderSeatsOwedBlock() {
      return this.seatsOwed !== null;
    },
    canAddSeats() {
      if (this.isFreePlan) {
        return false;
      }
      return this.subscriptionPermissions?.canAddSeats ?? true;
    },
    parsedNamespaceId() {
      return parseInt(this.namespaceId, 10);
    },
    permissionReason() {
      return this.subscriptionPermissions?.reason;
    },
    shouldShowModal() {
      return !this.canAddSeats && this.hasLimitedAccess;
    },
    shouldShowAddSeatsButton() {
      if (this.isLoading || !this.purchaseButtonLink) {
        return false;
      }
      return this.canAddSeats || this.hasLimitedAccess;
    },
    shouldShowExplorePaidPlansButton() {
      if (this.isLoading) {
        return false;
      }
      return this.isFreePlan;
    },
    isLoading() {
      return this.$apollo.loading;
    },
  },
  apollo: {
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: this.parsedNamespaceId,
        };
      },
      update: (data) => ({
        ...data.subscription,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error: (error) => {
        const { networkError } = error;
        if (networkError?.result?.errors.length) {
          networkError?.result?.errors.forEach(({ message }) => Sentry.captureException(message));
        }
        Sentry.captureException(error);
      },
    },
    plan: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.parsedNamespaceId,
        };
      },
      update: (data) => {
        return data?.subscription?.plan || {};
      },
      error: (error) => {
        Sentry.captureException(error);
      },
    },
  },
  methods: {
    handleAddSeats() {
      if (this.shouldShowModal) {
        this.showLimitedAccessModal = true;
        return;
      }

      this.trackAddSeats();
      visitUrl(this.purchaseButtonLink);
    },
    trackAddSeats() {
      this.track('click_button', { label: 'add_seats_saas', property: 'usage_quotas_page' });
    },
    trackExplorePlans() {
      this.track('click_button', { label: EXPLORE_PAID_PLANS_CLICKED });
    },
  },
};
</script>

<template>
  <div
    class="gl-bg-white gl-border-1 gl-border-gray-100 gl-border-solid gl-p-5 gl-rounded-base gl-display-flex"
  >
    <gl-skeleton-loader v-if="isLoading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <div v-else class="gl-flex-grow-1">
      <p
        v-if="shouldRenderSeatsUsedBlock"
        class="gl-font-size-h-display gl-font-bold gl-mb-3"
        data-testid="seats-used"
      >
        <span class="gl-relative gl-top-1">
          {{ seatsUsed }}
        </span>
        <span class="gl-font-lg">
          {{ $options.i18n.seatsUsedText }}
        </span>
        <gl-link
          :href="$options.helpLinks.seatsUsedLink"
          :aria-label="$options.i18n.seatsUsedHelpText"
          class="gl-ml-2 gl-relative"
        >
          <gl-icon name="question-o" />
        </gl-link>
      </p>
      <p
        v-if="shouldRenderSeatsOwedBlock"
        class="gl-font-size-h-display gl-font-bold gl-mb-0"
        data-testid="seats-owed"
      >
        <span class="gl-relative gl-top-1">
          {{ seatsOwed }}
        </span>
        <span class="gl-font-lg">
          {{ $options.i18n.seatsOwedText }}
        </span>
        <gl-link
          :href="$options.helpLinks.seatsOwedLink"
          :aria-label="$options.i18n.seatsOwedHelpText"
          class="gl-ml-2 gl-relative"
        >
          <gl-icon name="question-o" />
        </gl-link>
      </p>
    </div>
    <gl-button
      v-if="shouldShowAddSeatsButton"
      v-gl-modal-directive="'limited-access-modal-id'"
      category="primary"
      target="_blank"
      variant="confirm"
      class="gl-ml-3 gl-align-self-start"
      data-testid="purchase-button"
      @click="handleAddSeats"
    >
      {{ $options.i18n.addSeatsText }}
    </gl-button>
    <gl-button
      v-if="shouldShowExplorePaidPlansButton"
      :href="explorePlansPath"
      category="primary"
      target="_blank"
      variant="confirm"
      class="gl-ml-3 gl-align-self-start"
      data-testid="explore-paid-plans"
      @click="trackExplorePlans"
    >
      {{ $options.i18n.explorePlansText }}
    </gl-button>
    <limited-access-modal
      v-if="shouldShowModal"
      v-model="showLimitedAccessModal"
      :limited-access-reason="permissionReason"
    />
  </div>
</template>
