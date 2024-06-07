<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import reportsMixin from 'ee/vue_shared/security_reports/mixins/reports_mixin';
import CEWidgetOptions from '~/vue_merge_request_widget/mr_widget_options.vue';
import MrWidgetJiraAssociationMissing from './components/states/mr_widget_jira_association_missing.vue';
import MrWidgetPolicyViolation from './components/states/mr_widget_policy_violation.vue';
import MrWidgetGeoSecondaryNode from './components/states/mr_widget_secondary_geo_node.vue';
import WidgetContainer from './components/widget/app.vue';

export default {
  components: {
    GlSprintf,
    GlLink,
    WidgetContainer,
    MrWidgetGeoSecondaryNode,
    MrWidgetPolicyViolation,
    MrWidgetJiraAssociationMissing,
    BlockingMergeRequestsReport: () =>
      import('./components/blocking_merge_requests/blocking_merge_requests_report.vue'),
  },
  directives: {
    SafeHtml,
  },
  extends: CEWidgetOptions,
  mixins: [reportsMixin],
  methods: {
    getServiceEndpoints(store) {
      const base = CEWidgetOptions.methods.getServiceEndpoints(store);

      return {
        ...base,
        apiApprovalSettingsPath: store.apiApprovalSettingsPath,
      };
    },
  },
};
</script>
<template>
  <!-- eslint-disable vue/no-undef-components -->
  <div v-if="!loading" id="widget-state" class="mr-state-widget gl-mt-5">
    <header
      v-if="shouldRenderCollaborationStatus"
      class="gl-rounded-base gl-border-solid gl-border-1 gl-border-gray-100 gl-overflow-hidden mr-widget-workflow gl-mt-0!"
    >
      <mr-widget-alert-message v-if="shouldRenderCollaborationStatus" type="info">
        {{ s__('mrWidget|Members who can merge are allowed to add commits.') }}
      </mr-widget-alert-message>
    </header>
    <mr-widget-suggest-pipeline
      v-if="shouldSuggestPipelines"
      class="mr-widget-workflow"
      :pipeline-path="mr.mergeRequestAddCiConfigPath"
      :pipeline-svg-path="mr.pipelinesEmptySvgPath"
      :human-access="formattedHumanAccess"
      :user-callouts-path="mr.userCalloutsPath"
      :user-callout-feature-id="mr.suggestPipelineFeatureId"
      @dismiss="dismissSuggestPipelines"
    />
    <mr-widget-migrate-jenkins
      v-if="showRenderMigrateFromJenkins"
      class="mr-widget-workflow"
      :human-access="formattedHumanAccess"
      @dismiss="dismissMigrateFromJenkins"
    />
    <mr-widget-pipeline-container
      v-if="shouldRenderPipelines"
      :mr="mr"
      data-testid="pipeline-container"
    />
    <mr-widget-approvals v-if="shouldRenderApprovals" :mr="mr" :service="service" />
    <report-widget-container>
      <widget-container v-if="mr" :mr="mr" />
    </report-widget-container>
    <div class="mr-section-container mr-widget-workflow">
      <div v-if="hasAlerts" class="gl-overflow-hidden mr-widget-alert-container">
        <mr-widget-alert-message
          v-if="hasMergeError"
          type="danger"
          dismissible
          data-testid="merge_error"
        >
          <span v-safe-html="mergeError"></span>
        </mr-widget-alert-message>
        <mr-widget-alert-message
          v-if="showMergePipelineForkWarning"
          type="warning"
          :help-path="mr.mergeRequestPipelinesHelpPath"
        >
          {{
            s__(
              'mrWidget|If the last pipeline ran in the fork project, it may be inaccurate. Before merge, we advise running a pipeline in this project.',
            )
          }}
          <template #link-content>
            {{ __('Learn more') }}
          </template>
        </mr-widget-alert-message>
      </div>
      <blocking-merge-requests-report :mr="mr" />

      <div class="mr-widget-section">
        <template v-if="mergeBlockedComponentVisible">
          <mr-widget-auto-merge-enabled
            v-if="autoMergeEnabled"
            :mr="mr"
            :service="service"
            class="gl-border-b-1 gl-border-b-solid gl-border-gray-100"
          />
          <merge-checks :mr="mr" :service="service" />
        </template>
        <component :is="componentName" v-else :mr="mr" :service="service" />
        <ready-to-merge v-if="mr.commitsCount" :mr="mr" :service="service" />
      </div>
    </div>
    <mr-widget-pipeline-container
      v-if="shouldRenderMergedPipeline"
      class="js-post-merge-pipeline mr-widget-workflow"
      data-testid="merged-pipeline-container"
      :mr="mr"
      :is-post-merge="true"
    />
  </div>
  <loading v-else />
</template>
