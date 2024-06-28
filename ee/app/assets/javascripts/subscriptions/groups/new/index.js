import Vue from 'vue';
import App from './components/subscription_group_selector.vue';

export default () => {
  const el = document.getElementById('js-new-subscription-group');

  if (!el) return null;

  const { rootUrl } = el.dataset;
  const plansData = JSON.parse(el.dataset.plansData);
  const eligibleGroups = JSON.parse(el.dataset.eligibleGroups);

  return new Vue({
    el,
    components: {
      App,
    },
    render(createElement) {
      return createElement(App, {
        props: {
          rootUrl,
          plansData,
          eligibleGroups,
        },
      });
    },
  });
};
