import Vue from 'vue';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from './constants';
import { decomposeApprovers } from './utils';

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    assignedPolicyProject,
    disableScanPolicyUpdate,
    createAgentHelpPath,
    globalGroupApproversEnabled,
    maxActiveScanExecutionPoliciesReached,
    maxActiveScanResultPoliciesReached,
    maxActivePipelineExecutionPoliciesReached,
    maxScanExecutionPoliciesAllowed,
    maxScanResultPoliciesAllowed,
    maxPipelineExecutionPoliciesAllowed,
    namespaceId,
    namespacePath,
    policiesPath,
    policy,
    policyEditorEmptyStateSvgPath,
    policyType,
    roleApproverTypes,
    rootNamespacePath,
    customCiToggleEnabled,
    scanPolicyDocumentationPath,
    scanResultApprovers,
    softwareLicenses,
    timezones,
  } = el.dataset;

  const policyProject = JSON.parse(assignedPolicyProject);

  let parsedSoftwareLicenses;
  let parsedTimezones;

  try {
    parsedSoftwareLicenses = JSON.parse(softwareLicenses).map((license) => {
      return { value: license, text: license };
    });
  } catch {
    parsedSoftwareLicenses = [];
  }

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

  try {
    parsedTimezones = JSON.parse(timezones);
  } catch {
    parsedTimezones = [];
  }

  return new Vue({
    el,
    apolloProvider,
    provide: {
      createAgentHelpPath,
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      globalGroupApproversEnabled: parseBoolean(globalGroupApproversEnabled),
      maxActiveScanExecutionPoliciesReached: parseBoolean(maxActiveScanExecutionPoliciesReached),
      maxActivePipelineExecutionPoliciesReached: parseBoolean(
        maxActivePipelineExecutionPoliciesReached,
      ),
      maxActiveScanResultPoliciesReached: parseBoolean(maxActiveScanResultPoliciesReached),
      maxScanExecutionPoliciesAllowed,
      customCiToggleEnabled: parseBoolean(customCiToggleEnabled),
      maxScanResultPoliciesAllowed,
      maxPipelineExecutionPoliciesAllowed,
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
      parsedSoftwareLicenses,
      timezones: parsedTimezones,
      existingPolicy: policy ? { type: policyType, ...JSON.parse(policy) } : undefined,
      assignedPolicyProject: policyProject
        ? convertObjectPropsToCamelCase(policyProject)
        : DEFAULT_ASSIGNED_POLICY_PROJECT,
    },
    render(createElement) {
      return createElement(App);
    },
  });
};
