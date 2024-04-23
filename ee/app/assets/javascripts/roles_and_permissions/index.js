import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import CustomRolesApp from './components/app.vue';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCustomRolesApp = () => {
  const el = document.querySelector('#js-roles-and-permissions');

  if (!el) {
    return null;
  }

  const { documentationPath, emptyStateSvgPath, groupFullPath, newRolePath } = el.dataset;

  return new Vue({
    el,
    name: 'CustomRolesRoot',
    apolloProvider,
    provide: {
      documentationPath,
      emptyStateSvgPath,
      groupFullPath,
      newRolePath,
    },
    render(createElement) {
      return createElement(CustomRolesApp);
    },
  });
};
