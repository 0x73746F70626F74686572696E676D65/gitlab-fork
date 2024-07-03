<script>
import { GlCard, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { n__, __ } from '~/locale';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';

export const billableUsersURL = helpPagePath('subscriptions/self_managed/index', {
  anchor: 'billable-users',
});
export const trueUpURL = `${PROMO_URL}/pricing/licensing-faq/#what-does-users-over-license-mean`;

export const usersInSubscriptionUnlimited = __('Unlimited');

export const i18n = Object.freeze({
  billableUsersTitle: __('Billable users'),
  maximumUsersTitle: __('Maximum users'),
  usersOverSubscriptionTitle: __('Users over subscription'),
  billableUsersText: __(
    'This is the number of %{billableUsersLinkStart}billable users%{billableUsersLinkEnd} on your installation, and this is the minimum number you need to purchase when you renew your license.',
  ),
  maximumUsersText: __(
    'This is the highest peak of users on your installation since the license started.',
  ),
  usersInSubscriptionText: __(
    `Users with a Guest role or those who don't belong to a Project or Group will not use a seat from your license.`,
  ),
  usersOverSubscriptionText: __(
    `You'll be charged for %{trueUpLinkStart}users over license%{trueUpLinkEnd} on a quarterly or annual basis, depending on the terms of your agreement.`,
  ),
});

export default {
  links: {
    billableUsersURL,
    trueUpURL,
  },
  name: 'SubscriptionDetailsUserInfo',
  components: {
    GlCard,
    GlLink,
    GlSprintf,
  },
  props: {
    subscription: {
      type: Object,
      required: true,
    },
  },
  computed: {
    usersInSubscription() {
      return this.subscription.usersInLicenseCount ?? usersInSubscriptionUnlimited;
    },
    billableUsers() {
      return this.subscription.billableUsersCount;
    },
    maximumUsers() {
      return this.subscription.maximumUserCount;
    },
    usersOverSubscription() {
      return this.subscription.usersOverLicenseCount;
    },
    isUsersInSubscriptionVisible() {
      return this.subscription.plan === 'ultimate';
    },
    usersInSubscriptionTitle() {
      if (this.subscription.usersInLicenseCount) {
        return n__(
          'User in subscription',
          'Users in subscription',
          this.subscription.usersInLicenseCount,
        );
      }

      return __('Users in subscription');
    },
  },
  i18n,
};
</script>

<template>
  <div class="gl-grid sm:gl-grid-cols-2 gl-gap-5 gl-mb-6">
    <gl-card>
      <header>
        <h5 class="gl-font-normal gl-text-secondary gl-mt-0">{{ usersInSubscriptionTitle }}</h5>
        <h2 class="!gl-mt-0" data-testid="users-in-subscription">{{ usersInSubscription }}</h2>
      </header>
      <div v-if="isUsersInSubscriptionVisible" data-testid="users-in-subscription-desc">
        {{ $options.i18n.usersInSubscriptionText }}
      </div>
    </gl-card>

    <gl-card data-testid="billable-users">
      <header>
        <h5 class="gl-font-normal gl-text-secondary gl-mt-0">
          {{ $options.i18n.billableUsersTitle }}
        </h5>
        <h2 class="!gl-mt-0" data-testid="billable-users-count">{{ billableUsers }}</h2>
      </header>
      <div>
        <gl-sprintf :message="$options.i18n.billableUsersText">
          <template #billableUsersLink="{ content }">
            <gl-link :href="$options.links.billableUsersURL" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
    </gl-card>

    <gl-card data-testid="maximum-users">
      <header>
        <h5 class="gl-font-normal gl-text-secondary gl-mt-0">
          {{ $options.i18n.maximumUsersTitle }}
        </h5>
        <h2 class="!gl-mt-0">{{ maximumUsers }}</h2>
      </header>
      <div>{{ $options.i18n.maximumUsersText }}</div>
    </gl-card>

    <gl-card data-testid="users-over-license">
      <header>
        <h5 class="gl-font-normal gl-text-secondary gl-mt-0">
          {{ $options.i18n.usersOverSubscriptionTitle }}
        </h5>
        <h2 class="!gl-mt-0">{{ usersOverSubscription }}</h2>
      </header>
      <div>
        <gl-sprintf :message="$options.i18n.usersOverSubscriptionText">
          <template #trueUpLink="{ content }">
            <gl-link :href="$options.links.trueUpURL">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
    </gl-card>
  </div>
</template>
