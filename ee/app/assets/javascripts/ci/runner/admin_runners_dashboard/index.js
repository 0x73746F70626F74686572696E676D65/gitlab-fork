import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import AdminRunnersDashboardApp from './admin_runners_dashboard_app.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initAdminRunnersDashboard = (selector = '#js-admin-runners-dashboard') => {
  const el = document.querySelector(selector);

  const { adminRunnersPath, newRunnerPath } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    render(h) {
      return h(AdminRunnersDashboardApp, {
        props: {
          adminRunnersPath,
          newRunnerPath,
        },
      });
    },
  });
};
