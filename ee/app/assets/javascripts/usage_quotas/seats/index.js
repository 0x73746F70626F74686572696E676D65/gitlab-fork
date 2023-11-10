import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { parseBoolean } from '~/lib/utils/common_utils';
import SubscriptionSeats from 'ee/usage_quotas/seats/components/subscription_seats.vue';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { writeDataToApolloCache } from 'ee/usage_quotas/seats/graphql/utils';
import initialStore from './store';

Vue.use(Vuex);
Vue.use(VueApollo);

export default (containerId = 'js-seat-usage-app') => {
  const el = document.getElementById(containerId);

  if (!el) {
    return false;
  }

  const {
    fullPath,
    namespaceId,
    namespaceName,
    seatUsageExportPath,
    pendingMembersPagePath,
    pendingMembersCount,
    addSeatsHref,
    hasNoSubscription,
    maxFreeNamespaceSeats,
    explorePlansPath,
    enforcementFreeUserCapEnabled,
  } = el.dataset;

  const store = new Vuex.Store(
    initialStore({
      namespaceId,
      namespaceName,
      seatUsageExportPath,
      pendingMembersPagePath,
      pendingMembersCount,
      addSeatsHref,
      hasNoSubscription: parseBoolean(hasNoSubscription),
      maxFreeNamespaceSeats: parseInt(maxFreeNamespaceSeats, 10),
      explorePlansPath,
      enforcementFreeUserCapEnabled: parseBoolean(enforcementFreeUserCapEnabled),
    }),
  );

  return new Vue({
    el,
    name: 'SeatsUsageApp',
    apolloProvider: writeDataToApolloCache(apolloProvider),
    provide: {
      explorePlansPath,
      fullPath,
    },
    store,
    render(createElement) {
      return createElement(SubscriptionSeats);
    },
  });
};
