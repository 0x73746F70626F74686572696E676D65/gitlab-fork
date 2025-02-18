import Vue from 'vue';
import VueApollo from 'vue-apollo';
import mountApprovals from 'ee/approvals/mr_edit/mount_mr_edit';
import mountApprovalsPromo from 'ee/approvals/mr_edit/mount_mr_promo';
import mountBlockingMergeRequestsInput from 'ee/projects/merge_requests/blocking_mr_input';
import initCheckFormState from '~/pages/projects/merge_requests/edit/check_form_state';
import SummaryCodeChanges from 'ee/merge_requests/components/summarize_code_changes.vue';
import createDefaultClient from '~/lib/graphql';

export default () => {
  const editMrApp = mountApprovals(document.getElementById('js-mr-approvals-input'));
  mountApprovalsPromo(document.getElementById('js-mr-approvals-promo'));
  mountBlockingMergeRequestsInput(document.getElementById('js-blocking-merge-requests-input'));
  if (editMrApp) {
    editMrApp.$on('hidden-inputs-mounted', initCheckFormState);
  }

  const el = document.querySelector('.js-summarize-code-changes');

  if (el) {
    Vue.use(VueApollo);

    const apolloProvider = new VueApollo({
      defaultClient: createDefaultClient(),
    });

    const { projectId, sourceBranch, targetBranch } = el.dataset;

    // eslint-disable-next-line no-new
    new Vue({
      el,
      apolloProvider,
      provide: {
        projectId,
        sourceBranch,
        targetBranch,
      },
      render(h) {
        return h(SummaryCodeChanges);
      },
    });
  }
};
