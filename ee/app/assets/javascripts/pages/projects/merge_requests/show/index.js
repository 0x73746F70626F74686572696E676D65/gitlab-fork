import '~/pages/projects/merge_requests/show';
import Vue from 'vue';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import { parseBoolean } from '~/lib/utils/common_utils';

const initVerificationAlert = (el) => {
  return new Vue({
    el,
    name: 'PipelineAccountVerificationAlertRoot',
    provide: {
      identityVerificationRequired: parseBoolean(el.dataset.identityVerificationRequired),
      identityVerificationPath: el.dataset.identityVerificationPath,
    },
    render(createElement) {
      return createElement(PipelineAccountVerificationAlert, { class: 'gl-mt-3' });
    },
  });
};

const el = document.querySelector('.js-verification-alert');
if (el) {
  initVerificationAlert(el);
}
