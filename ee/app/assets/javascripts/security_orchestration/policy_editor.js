import Vue from 'vue';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import NewPolicyApp from './components/policy_editor/new_policy.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from './constants';
import { decomposeApprovers } from './utils';

export default (el, namespaceType) => {
  const {
    assignedPolicyProject,
    disableScanPolicyUpdate,
    createAgentHelpPath,
    globalGroupApproversEnabled,
    namespaceId,
    namespacePath,
    policiesPath,
    policy,
    policyEditorEmptyStateSvgPath,
    policyType,
    roleApproverTypes,
    rootNamespacePath,
    scanPolicyDocumentationPath,
    scanResultApprovers,
    softwareLicenses,
  } = el.dataset;

  const policyProject = JSON.parse(assignedPolicyProject);

  let scanResultPolicyApprovers;

  try {
    scanResultPolicyApprovers = decomposeApprovers(
      JSON.parse(scanResultApprovers).map((approver) => {
        return typeof approver === 'object' ? convertObjectPropsToCamelCase(approver) : approver;
      }),
    );
  } catch {
    scanResultPolicyApprovers = {};
  }

  return new Vue({
    el,
    apolloProvider,
    provide: {
      createAgentHelpPath,
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      globalGroupApproversEnabled: parseBoolean(globalGroupApproversEnabled),
      namespaceId,
      namespacePath,
      namespaceType,
      policyEditorEmptyStateSvgPath,
      policyType,
      policiesPath,
      roleApproverTypes: JSON.parse(roleApproverTypes),
      rootNamespacePath,
      scanPolicyDocumentationPath,
      scanResultPolicyApprovers,
      softwareLicenses,
      existingPolicy: policy ? { type: policyType, ...JSON.parse(policy) } : undefined,
      assignedPolicyProject: policyProject
        ? convertObjectPropsToCamelCase(policyProject)
        : DEFAULT_ASSIGNED_POLICY_PROJECT,
    },
    render(createElement) {
      return createElement(NewPolicyApp);
    },
  });
};
