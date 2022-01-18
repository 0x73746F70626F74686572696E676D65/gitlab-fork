import Vue from 'vue';
import ensureData from '~/ensure_data';
import apolloProvider from '../buy_addons_shared/graphql';
import { writeInitialDataToApolloCache } from '../buy_addons_shared/utils';
import { planTags } from 'ee/subscriptions/buy_addons_shared/constants';
import App from 'ee/subscriptions/buy_addons_shared/components/app.vue';

export default (el) => {
  if (!el) {
    return null;
  }

  const extendedApp = ensureData(App, {
    parseData: writeInitialDataToApolloCache.bind(null, apolloProvider),
    data: el.dataset,
    shouldLog: true,
    provide: {
      tags: [planTags.CI_1000_MINUTES_PLAN],
    },
  });

  return new Vue({
    el,
    name: 'BuyCIMinutes',
    apolloProvider,
    render(createElement) {
      return createElement(extendedApp);
    },
  });
};
