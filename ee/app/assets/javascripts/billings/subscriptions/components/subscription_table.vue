<script>
import { GlButton, GlCard, GlLoadingIcon } from '@gitlab/ui';
import { escape } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import { getSubscriptionData } from 'ee/fulfillment/shared_queries/subscription_actions.customer.query.graphql';
import { getTemporaryExtensionData } from 'ee/fulfillment/shared_queries/temporary_extension.customer.query.graphql';
import { removeTrialSuffix } from 'ee/billings/billings_util';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import Tracking from '~/tracking';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SubscriptionTableRow from './subscription_table_row.vue';

const createButtonProps = (text, href, testId, clickHandler = () => {}) => {
  return {
    text,
    href,
    testId,
    dataQaSelector: testId,
    clickHandler,
  };
};

export default {
  name: 'SubscriptionTable',
  components: {
    GlButton,
    GlCard,
    GlLoadingIcon,
    SubscriptionTableRow,
  },
  mixins: [glFeatureFlagsMixin(), Tracking.mixin()],
  inject: {
    planRenewHref: {
      default: '',
    },
    namespaceId: {
      default: null,
    },
    customerPortalUrl: {
      default: '',
    },
    namespaceName: {
      default: '',
    },
    addSeatsHref: {
      default: '',
    },
    planName: {
      default: '',
    },
    refreshSeatsHref: {
      default: '',
    },
    readOnly: {
      default: false,
    },
  },
  data() {
    return {
      subscription: null,
    };
  },
  apollo: {
    subscription: {
      query: getSubscriptionData,
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      skip() {
        return this.isFreePlan;
      },
    },
    temporaryExtension: {
      query: getTemporaryExtensionData,
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      skip() {
        return this.isFreePlan;
      },
      error(error) {
        this.handleError(error);
      },
    },
  },
  computed: {
    ...mapState(['isLoadingSubscription', 'hasErrorSubscription', 'plan', 'tables', 'endpoint']),
    ...mapGetters(['isFreePlan', 'tableKey']),
    isSubscription() {
      return !this.isFreePlan;
    },
    subscriptionHeader() {
      const planName = this.isFreePlan ? s__('SubscriptionTable|Free') : this.escapedPlanName;
      const suffix = this.isSubscription && this.plan.trial ? s__('SubscriptionTable|Trial') : '';

      return `${this.namespaceName}: ${planName} ${suffix}`;
    },
    escapedPlanName() {
      if (!this.planName) {
        return '';
      }
      return escape(removeTrialSuffix(this.planName));
    },
    canRefreshSeats() {
      return this.glFeatures.refreshBillingsSeats;
    },
    addSeatsButton() {
      return this.isSubscription && this.subscription?.canAddSeats
        ? createButtonProps(
            s__('SubscriptionTable|Add seats'),
            this.addSeatsHref,
            'add-seats-button',
            this.trackClick,
          )
        : null;
    },
    renewButton() {
      return this.subscription?.canRenew
        ? createButtonProps(s__('SubscriptionTable|Renew'), this.planRenewHref, 'renew-button')
        : null;
    },
    manageButton() {
      return this.isSubscription
        ? createButtonProps(
            s__('SubscriptionTable|Manage'),
            this.customerPortalUrl,
            'manage-button',
          )
        : null;
    },
    temporaryExtensionEndDate() {
      return this.temporaryExtension?.endDate;
    },
    nextTermStartDate() {
      return this.subscription?.nextTermStartDate;
    },
    buttons() {
      return [this.addSeatsButton, this.renewButton, this.manageButton].filter(Boolean);
    },
    visibleRows() {
      return this.tables[this.tableKey].rows;
    },
    isLoading() {
      return this.isLoadingSubscription || this.$apollo.loading;
    },
  },
  created() {
    this.fetchSubscription();
  },
  methods: {
    ...mapActions(['fetchSubscription']),
    isLast(index) {
      return index === this.visibleRows.length - 1;
    },
    async refreshSeats() {
      try {
        await axios.post(this.refreshSeatsHref);

        this.fetchSubscription();
      } catch (error) {
        createAlert({
          message: s__('SubscriptionTable|Something went wrong trying to refresh seats'),
          captureError: true,
          error,
        });
      }
    },
    trackClick() {
      this.track('click_button', { label: 'add_seats_saas', property: 'billing_page' });
    },
    handleError(error) {
      Sentry.captureException(error);
    },
  },
};
</script>

<template>
  <div>
    <gl-card
      v-if="!isLoading && !hasErrorSubscription"
      class="gl-new-card subscription-table js-subscription-table"
      header-class="gl-new-card-header"
      body-class="gl-new-card-body gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row gl-lg-flex-direction-column! flex-grid gl-p-0"
    >
      <template #header>
        <div class="gl-new-card-title-wrapper">
          <h5 class="gl-new-card-title" data-testid="subscription-header">
            {{ subscriptionHeader }}
          </h5>
        </div>
        <div v-if="!readOnly" class="gl-new-card-actions gl-display-flex">
          <gl-button
            v-for="(button, index) in buttons"
            :key="button.text"
            :href="button.href"
            :class="{ 'gl-ml-3': index !== 0 }"
            :data-testid="button.testId"
            size="small"
            target="_blank"
            @click="button.clickHandler"
            >{{ button.text }}</gl-button
          >
          <gl-button
            v-if="canRefreshSeats"
            :class="{ 'gl-ml-2': buttons.length !== 0 }"
            data-testid="refresh-seats"
            size="small"
            @click="refreshSeats"
            >{{ s__('SubscriptionTable|Refresh Seats') }}</gl-button
          >
        </div>
      </template>

      <subscription-table-row
        v-for="(row, i) in visibleRows"
        :key="`subscription-rows-${i}`"
        :last="isLast(i)"
        :header="row.header"
        :columns="row.columns"
        :is-free-plan="isFreePlan"
        :temporary-extension-end-date="temporaryExtensionEndDate"
        :next-term-start-date="nextTermStartDate"
      />
    </gl-card>

    <gl-loading-icon
      v-else-if="isLoading && !hasErrorSubscription"
      :label="s__('SubscriptionTable|Loading subscriptions')"
      size="lg"
      class="gl-mt-3 gl-mb-3"
    />
  </div>
</template>
