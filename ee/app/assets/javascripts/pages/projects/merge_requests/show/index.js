import '~/pages/projects/merge_requests/show';
import Vue from 'vue';
import ConcurrentPipelinesVerificationAlert from 'ee/vue_shared/components/identity_verification/concurrent_pipelines_verification_alert.vue';

const initVerificationAlert = (el) => {
  return new Vue({
    el,
    name: 'ConcurrentPipelinesVerificationAlertRoot',
    provide: { identityVerificationPath: el.dataset.identityVerificationPath },
    render(createElement) {
      return createElement(ConcurrentPipelinesVerificationAlert, { class: 'gl-mt-3' });
    },
  });
};

const el = document.querySelector('.js-verification-alert');
if (el) {
  initVerificationAlert(el);
}
