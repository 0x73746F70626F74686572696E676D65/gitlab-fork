import Vue from 'vue';
import WhatsNewApp from './components/app.vue';
import store from './store';

let whatsNewApp;

export default (el, versionDigest) => {
  if (whatsNewApp) {
    store.dispatch('openDrawer');
  } else {
    whatsNewApp = new Vue({
      el,
      store,
      render(createElement) {
        return createElement(WhatsNewApp, {
          props: {
            versionDigest,
          },
        });
      },
    });
  }
};
