import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { parseBoolean } from '~/lib/utils/common_utils';

import createDefaultClient from '~/lib/graphql';

import { createRouter } from 'ee/compliance_dashboard/router';

export default () => {
  const el = document.getElementById('js-compliance-report');

  const {
    basePath,
    mergeCommitsCsvExportPath,
    violationsCsvExportPath,
    projectFrameworksCsvExportPath,
    adherencesCsvExportPath,
    frameworksCsvExportPath,
    groupPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorWebUrl,
    pipelineConfigurationFullPathEnabled,
    pipelineConfigurationEnabled,
    featurePipelineMaintenanceModeEnabled,
    pipelineExecutionPolicyPath,
    migratePipelineToPolicyPath,
    groupSecurityPoliciesPath,
    disableScanPolicyUpdate,
    projectId,
  } = el.dataset;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const globalProjectId = projectId ? parseInt(projectId, 10) : null;

  const router = createRouter(basePath, {
    mergeCommitsCsvExportPath,
    globalProjectId,
    groupPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorWebUrl,
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'ComplianceReportsApp',
    router,
    provide: {
      namespaceType: 'group',
      groupPath,
      pipelineConfigurationFullPathEnabled: parseBoolean(pipelineConfigurationFullPathEnabled),
      pipelineConfigurationEnabled: parseBoolean(pipelineConfigurationEnabled),
      featurePipelineMaintenanceModeEnabled: parseBoolean(featurePipelineMaintenanceModeEnabled),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      mergeCommitsCsvExportPath,
      violationsCsvExportPath,
      projectFrameworksCsvExportPath,
      adherencesCsvExportPath,
      frameworksCsvExportPath,
      pipelineExecutionPolicyPath,
      migratePipelineToPolicyPath,
      groupSecurityPoliciesPath,
    },
    render: (createElement) => createElement('router-view'),
  });
};
