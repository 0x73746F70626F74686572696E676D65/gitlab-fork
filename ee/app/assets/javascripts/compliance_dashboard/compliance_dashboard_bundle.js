import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { parseBoolean } from '~/lib/utils/common_utils';

import createDefaultClient from '~/lib/graphql';

import { createRouter } from 'ee/compliance_dashboard/router';
import {
  ROUTE_FRAMEWORKS,
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_PROJECTS,
} from './constants';

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
    rootAncestorComplianceCenterPath,
    pipelineConfigurationFullPathEnabled,
    pipelineConfigurationEnabled,
    pipelineExecutionPolicyPath,
    migratePipelineToPolicyPath,
    groupSecurityPoliciesPath,
    disableScanPolicyUpdate,
    projectId,

    featurePipelineMaintenanceModeEnabled,
    featureAdherenceReportEnabled,
    featureViolationsReportEnabled,
    featureFrameworksReportEnabled,
    featureProjectsReportEnabled,
    featureSecurityPoliciesEnabled,
  } = el.dataset;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const globalProjectId = projectId ? parseInt(projectId, 10) : null;

  const routes = Object.entries({
    [ROUTE_STANDARDS_ADHERENCE]: parseBoolean(featureAdherenceReportEnabled),
    [ROUTE_VIOLATIONS]: parseBoolean(featureViolationsReportEnabled),
    [ROUTE_FRAMEWORKS]: parseBoolean(featureFrameworksReportEnabled),
    [ROUTE_PROJECTS]: parseBoolean(featureProjectsReportEnabled),
  })
    .filter(([, status]) => status)
    .map(([route]) => route);

  const router = createRouter(basePath, {
    mergeCommitsCsvExportPath,
    globalProjectId,
    groupPath,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes,
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'ComplianceReportsApp',
    router,
    provide: {
      namespaceType: 'group',
      groupPath,
      rootAncestorPath,
      pipelineConfigurationFullPathEnabled: parseBoolean(pipelineConfigurationFullPathEnabled),
      pipelineConfigurationEnabled: parseBoolean(pipelineConfigurationEnabled),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      mergeCommitsCsvExportPath,
      violationsCsvExportPath,
      projectFrameworksCsvExportPath,
      adherencesCsvExportPath,
      frameworksCsvExportPath,
      pipelineExecutionPolicyPath,
      migratePipelineToPolicyPath,
      groupSecurityPoliciesPath,

      featurePipelineMaintenanceModeEnabled: parseBoolean(featurePipelineMaintenanceModeEnabled),
      featureSecurityPoliciesEnabled: parseBoolean(featureSecurityPoliciesEnabled),
    },

    render: (createElement) => createElement('router-view'),
  });
};
