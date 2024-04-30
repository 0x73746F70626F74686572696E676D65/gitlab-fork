import { visitUrl } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import * as types from './mutation_types';
import { isSameVulnerability } from './utils';

const updateFindingFromGraphqlResponse = (finding, updated) => {
  const f = finding; // Avoids eslint no-param-reassign error.
  const stateTransitions = updated.stateTransitions.nodes;

  f.state = stateTransitions.at(-1).toState.toLowerCase();
  f.state_transitions = stateTransitions.map(convertObjectPropsToSnakeCase);
};

export default {
  [types.SET_PIPELINE_ID](state, payload) {
    state.pipelineId = payload;
  },
  [types.SET_SOURCE_BRANCH](state, payload) {
    state.sourceBranch = payload;
  },
  [types.SET_VULNERABILITIES_ENDPOINT](state, payload) {
    state.vulnerabilitiesEndpoint = payload;
  },
  [types.REQUEST_VULNERABILITIES](state) {
    state.isLoadingVulnerabilities = true;
    state.errorLoadingVulnerabilities = false;
    state.loadingVulnerabilitiesErrorCode = null;
  },
  [types.RECEIVE_VULNERABILITIES_SUCCESS](state, payload) {
    state.isLoadingVulnerabilities = false;
    state.pageInfo = payload.pageInfo;
    state.vulnerabilities = payload.vulnerabilities;
    state.selectedVulnerabilities = {};
  },
  [types.RECEIVE_VULNERABILITIES_ERROR](state, errorCode = null) {
    state.isLoadingVulnerabilities = false;
    state.errorLoadingVulnerabilities = true;
    state.loadingVulnerabilitiesErrorCode = errorCode;
  },
  [types.SET_VULNERABILITIES_PAGE](state, payload) {
    state.pageInfo = { ...state.pageInfo, page: payload };
  },
  [types.SET_MODAL_DATA](state, payload) {
    const { vulnerability } = payload;

    state.modal.title = vulnerability.name;
    state.modal.project.value = vulnerability.project?.full_name;
    state.modal.project.url = vulnerability.project?.full_path;

    state.modal.vulnerability = vulnerability;
    state.modal.vulnerability.isDismissed = Boolean(vulnerability.dismissal_feedback);
    state.modal.error = null;
    state.modal.isCommentingOnDismissal = false;
  },
  [types.REQUEST_CREATE_ISSUE](state) {
    state.isCreatingIssue = true;
    state.modal.error = null;
  },
  [types.RECEIVE_CREATE_ISSUE_SUCCESS](state, payload) {
    // We don't cancel the loading state here because we're navigating away from the page
    visitUrl(payload.securityFindingCreateIssue.issue.webUrl);
  },
  [types.RECEIVE_CREATE_ISSUE_ERROR](state) {
    state.isCreatingIssue = false;
    state.modal.error = __('There was an error creating the issue');
  },
  [types.REQUEST_DISMISS_VULNERABILITY](state) {
    state.isDismissingVulnerability = true;
    state.modal.error = null;
  },
  [types.RECEIVE_DISMISS_VULNERABILITY_SUCCESS](state, payload) {
    const vulnerability = state.vulnerabilities.find((vuln) =>
      isSameVulnerability(vuln, payload.vulnerability),
    );
    const updated = payload.data.securityFindingDismiss.securityFinding.vulnerability;
    updateFindingFromGraphqlResponse(vulnerability, updated);

    state.isDismissingVulnerability = false;
    state.modal.vulnerability.isDismissed = true;
  },
  [types.RECEIVE_DISMISS_VULNERABILITY_ERROR](state) {
    state.isDismissingVulnerability = false;
    state.modal.error = s__('SecurityReports|There was an error dismissing the vulnerability.');
  },
  [types.REQUEST_DISMISS_SELECTED_VULNERABILITIES](state) {
    state.isDismissingVulnerabilities = true;
  },
  [types.RECEIVE_DISMISS_SELECTED_VULNERABILITIES_SUCCESS](state) {
    state.isDismissingVulnerabilities = false;
    state.selectedVulnerabilities = {};
  },
  [types.RECEIVE_DISMISS_SELECTED_VULNERABILITIES_ERROR](state) {
    state.isDismissingVulnerabilities = false;
  },
  [types.SELECT_VULNERABILITY](state, id) {
    if (state.selectedVulnerabilities[id]) {
      return;
    }

    state.selectedVulnerabilities = {
      ...state.selectedVulnerabilities,
      [id]: true,
    };
  },
  [types.DESELECT_VULNERABILITY](state, id) {
    const selectedVulnerabilitiesCopy = { ...state.selectedVulnerabilities };
    delete selectedVulnerabilitiesCopy[id];

    state.selectedVulnerabilities = selectedVulnerabilitiesCopy;
  },
  [types.SELECT_ALL_VULNERABILITIES](state) {
    state.selectedVulnerabilities = state.vulnerabilities.reduce(
      (acc, { id }) => Object.assign(acc, { [id]: true }),
      {},
    );
  },
  [types.DESELECT_ALL_VULNERABILITIES](state) {
    state.selectedVulnerabilities = {};
  },
  [types.REQUEST_ADD_DISMISSAL_COMMENT](state) {
    state.isDismissingVulnerability = true;
    state.modal.error = null;
  },
  [types.RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS](state, payload) {
    const vulnerability = state.vulnerabilities.find((vuln) =>
      isSameVulnerability(vuln, payload.vulnerability),
    );
    if (vulnerability) {
      const updated = payload.data.securityFindingDismiss.securityFinding.vulnerability;
      updateFindingFromGraphqlResponse(vulnerability, updated);

      state.isDismissingVulnerability = false;
      state.modal.vulnerability.isDismissed = true;
    }
  },
  [types.RECEIVE_ADD_DISMISSAL_COMMENT_ERROR](state) {
    state.isDismissingVulnerability = false;
    state.modal.error = s__('SecurityReports|There was an error adding the comment.');
  },
  [types.REQUEST_DELETE_DISMISSAL_COMMENT](state) {
    state.isDismissingVulnerability = true;
    state.modal.error = null;
  },
  [types.RECEIVE_DELETE_DISMISSAL_COMMENT_SUCCESS](state, payload) {
    const vulnerability = state.vulnerabilities.find((vuln) => vuln.id === payload.id);
    if (vulnerability) {
      const updated = payload.data.securityFindingDismiss.securityFinding.vulnerability;
      updateFindingFromGraphqlResponse(vulnerability, updated);

      state.isDismissingVulnerability = false;
      state.modal.vulnerability.isDismissed = true;
    }
  },
  [types.RECEIVE_DELETE_DISMISSAL_COMMENT_ERROR](state) {
    state.isDismissingVulnerability = false;
    state.modal.error = s__('SecurityReports|There was an error deleting the comment.');
  },
  [types.REQUEST_REVERT_DISMISSAL](state) {
    state.isDismissingVulnerability = true;
    state.modal.error = null;
  },
  [types.RECEIVE_REVERT_DISMISSAL_SUCCESS](state, payload) {
    const vulnerability = state.vulnerabilities.find((vuln) =>
      isSameVulnerability(vuln, payload.vulnerability),
    );
    const updated = payload.data.securityFindingRevertToDetected.securityFinding.vulnerability;
    updateFindingFromGraphqlResponse(vulnerability, updated);

    state.isDismissingVulnerability = false;
    state.modal.vulnerability.isDismissed = false;
  },
  [types.RECEIVE_REVERT_DISMISSAL_ERROR](state) {
    state.isDismissingVulnerability = false;
    state.modal.error = s__('SecurityReports|There was an error reverting the dismissal.');
  },
  [types.SHOW_DISMISSAL_DELETE_BUTTONS](state) {
    state.modal.isShowingDeleteButtons = true;
  },
  [types.HIDE_DISMISSAL_DELETE_BUTTONS](state) {
    state.modal.isShowingDeleteButtons = false;
  },
  [types.REQUEST_CREATE_MERGE_REQUEST](state) {
    state.isCreatingMergeRequest = true;
    state.modal.error = null;
  },
  [types.RECEIVE_CREATE_MERGE_REQUEST_SUCCESS](state, payload) {
    const url = payload.merge_request_links.at(-1).merge_request_path;
    // We don't cancel the loading state here because we're navigating away from the page
    visitUrl(url);
  },
  [types.RECEIVE_CREATE_MERGE_REQUEST_ERROR](state) {
    state.isCreatingIssue = false;
    state.isCreatingMergeRequest = false;
    state.modal.error = s__('SecurityReports|There was an error creating the merge request');
  },
  [types.OPEN_DISMISSAL_COMMENT_BOX](state) {
    state.modal.isCommentingOnDismissal = true;
  },
  [types.CLOSE_DISMISSAL_COMMENT_BOX](state) {
    state.modal.isShowingDeleteButtons = false;
    state.modal.isCommentingOnDismissal = false;
    state.modal.isShowingDeleteButtons = false;
  },
  [types.SET_IS_CREATING_ISSUE](state, isCreatingIssue) {
    state.isCreatingIssue = isCreatingIssue;
  },
  [types.SET_EXTERNAL_ISSUE_LINKS](state, payload) {
    const vulnerability = state.vulnerabilities.find((vuln) =>
      isSameVulnerability(vuln, payload.vulnerability),
    );

    vulnerability.external_issue_links.push({ external_issue_details: payload.externalIssue });
  },
};
