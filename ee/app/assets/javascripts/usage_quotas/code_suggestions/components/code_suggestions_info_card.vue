<script>
import {
  GlCard,
  GlLink,
  GlSprintf,
  GlButton,
  GlSkeletonLoader,
  GlModalDirective,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, __ } from '~/locale';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  codeSuggestionsLearnMoreLink,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import { addSeatsText } from 'ee/usage_quotas/seats/constants';
import Tracking from '~/tracking';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import { ADD_ON_PURCHASE_FETCH_ERROR_CODE } from 'ee/usage_quotas/error_constants';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import { localeDateFormat } from '~/lib/utils/datetime_utility';

export default {
  name: 'CodeSuggestionsUsageInfoCard',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    description: s__(
      `CodeSuggestions|%{linkStart}Code Suggestions%{linkEnd} uses generative AI to suggest code while you're developing.`,
    ),
    title: s__('CodeSuggestions|%{title}'),
    addSeatsText,
    subscriptionStartDate: __('Subscription start date'),
    subscriptionEndDate: __('Subscription end date'),
    notAvailable: __('Not available'),
  },
  components: {
    GlButton,
    GlCard,
    GlLink,
    GlSprintf,
    UsageStatistics,
    GlSkeletonLoader,
    LimitedAccessModal,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [Tracking.mixin()],
  inject: [
    'addDuoProHref',
    'isSaaS',
    'subscriptionName',
    'subscriptionStartDate',
    'subscriptionEndDate',
  ],
  props: {
    groupId: {
      type: String,
      required: false,
      default: null,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (val) => [DUO_PRO, DUO_ENTERPRISE].includes(val),
    },
  },
  data() {
    return {
      showLimitedAccessModal: false,
    };
  },
  computed: {
    parsedGroupId() {
      return parseInt(this.groupId, 10);
    },
    shouldShowAddSeatsButton() {
      if (this.isLoading) {
        return false;
      }
      return true;
    },
    hasNoRequestInformation() {
      return !(this.groupId || this.subscriptionName);
    },
    isLoading() {
      return this.$apollo.queries.subscriptionPermissions.loading;
    },
    trackingPreffix() {
      return this.isSaaS ? 'saas' : 'sm';
    },
    shouldShowModal() {
      return !this.subscriptionPermissions?.canAddDuoProSeats && this.hasLimitedAccess;
    },
    hasLimitedAccess() {
      return LIMITED_ACCESS_KEYS.includes(this.permissionReason);
    },
    permissionReason() {
      return this.subscriptionPermissions?.reason;
    },
    duoTitle() {
      return this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE;
    },
    startDate() {
      const date = this.subscription?.startDate || this.subscriptionStartDate;
      return date ? this.formattedDate(date) : this.$options.i18n.notAvailable;
    },
    endDate() {
      const date = this.subscription?.endDate || this.subscriptionEndDate;
      return date ? this.formattedDate(date) : this.$options.i18n.notAvailable;
    },
  },
  apollo: {
    subscription: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.parsedGroupId,
        };
      },
      skip() {
        return !this.groupId;
      },
      error: (error) => {
        Sentry.captureException(error);
      },
    },
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return this.groupId
          ? { namespaceId: this.parsedGroupId }
          : { subscriptionName: this.subscriptionName };
      },
      skip() {
        return this.hasNoRequestInformation;
      },
      update: (data) => ({
        canAddDuoProSeats: data.subscription?.canAddDuoProSeats,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.$emit('error', errorWithCause);
        Sentry.captureException(error, {
          tags: {
            vue_component: this.$options.name,
          },
        });
      },
    },
  },
  methods: {
    handleAddDuoProClick() {
      this.track('click_button', {
        label: `add_duo_pro_${this.trackingPreffix}`,
        property: 'usage_quotas_page',
      });
    },
    handleAddSeats() {
      if (this.shouldShowModal) {
        this.showLimitedAccessModal = true;
        return;
      }

      this.handleAddDuoProClick();
      visitUrl(this.addDuoProHref);
    },
    formattedDate(date) {
      const [year, month, day] = date.split('-');
      return localeDateFormat.asDate.format(new Date(year, month - 1, day));
    },
  },
};
</script>
<template>
  <gl-card class="gl-p-3">
    <gl-skeleton-loader v-if="isLoading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>
    <usage-statistics v-else>
      <template #description>
        <h4 class="gl-font-bold gl-m-0" data-testid="title">
          {{ sprintf($options.i18n.title, { title: duoTitle }) }}
        </h4>
      </template>
      <template #additional-info>
        <p class="gl-mt-5" data-testid="description">
          <gl-sprintf :message="$options.i18n.description">
            <template #link="{ content }">
              <gl-link :href="$options.helpLinks.codeSuggestionsLearnMoreLink" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
        <div data-testid="subscription-info">
          <div class="gl-flex gl-gap-3">
            <span class="gl-basis-1/3 gl-font-bold gl-min-w-20">{{
              $options.i18n.subscriptionStartDate
            }}</span>
            <span>{{ startDate }}</span>
          </div>
          <div class="gl-flex gl-mt-2 gl-gap-3">
            <span class="gl-basis-1/3 gl-font-bold gl-min-w-20">{{
              $options.i18n.subscriptionEndDate
            }}</span>
            <span>{{ endDate }}</span>
          </div>
        </div>
      </template>
      <template #actions>
        <gl-button
          v-if="shouldShowAddSeatsButton"
          v-gl-modal-directive="'limited-access-modal-id'"
          category="primary"
          target="_blank"
          variant="confirm"
          size="small"
          class="gl-ml-3 gl-align-self-start"
          data-testid="purchase-button"
          @click="handleAddSeats"
        >
          {{ $options.i18n.addSeatsText }}
        </gl-button>
        <limited-access-modal
          v-if="shouldShowModal"
          v-model="showLimitedAccessModal"
          :limited-access-reason="permissionReason"
        />
      </template>
    </usage-statistics>
  </gl-card>
</template>
