import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PipelineTabs from 'ee_else_ce/pipelines/components/pipeline_tabs.vue';
import { removeParams, updateHistory } from '~/lib/utils/url_utility';
import { TAB_QUERY_PARAM } from '~/pipelines/constants';
import { parseBoolean } from '~/lib/utils/common_utils';
import { getPipelineDefaultTab, reportToSentry } from './utils';

Vue.use(VueApollo);

const createPipelineTabs = (selector, apolloProvider) => {
  const el = document.querySelector(selector);

  if (!el) return;

  const { dataset } = document.querySelector(selector);
  const {
    canGenerateCodequalityReports,
    codequalityReportDownloadPath,
    downloadablePathForReportType,
    exposeSecurityDashboard,
    exposeLicenseScanningData,
    graphqlResourceEtag,
    pipelineIid,
    pipelineProjectPath,
  } = dataset;

  const defaultTabValue = getPipelineDefaultTab(window.location.href);

  updateHistory({
    url: removeParams([TAB_QUERY_PARAM]),
    title: document.title,
    replace: true,
  });

  // eslint-disable-next-line no-new
  new Vue({
    el: selector,
    components: {
      PipelineTabs,
    },
    apolloProvider,
    provide: {
      canGenerateCodequalityReports: parseBoolean(canGenerateCodequalityReports),
      codequalityReportDownloadPath,
      defaultTabValue,
      downloadablePathForReportType,
      exposeSecurityDashboard: parseBoolean(exposeSecurityDashboard),
      exposeLicenseScanningData: parseBoolean(exposeLicenseScanningData),
      graphqlResourceEtag,
      pipelineIid,
      pipelineProjectPath,
    },
    errorCaptured(err, _vm, info) {
      reportToSentry('pipeline_tabs', `error: ${err}, info: ${info}`);
    },
    render(createElement) {
      return createElement(PipelineTabs);
    },
  });
};

export { createPipelineTabs };
