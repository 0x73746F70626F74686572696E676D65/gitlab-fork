<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import reportsMixin from 'ee/vue_shared/security_reports/mixins/reports_mixin';
import CEWidgetOptions from '~/vue_merge_request_widget/mr_widget_options.vue';
import MrWidgetAlertMessage from '~/vue_merge_request_widget/components/mr_widget_alert_message.vue';
import MrWidgetSuggestPipeline from '~/vue_merge_request_widget/components/mr_widget_suggest_pipeline.vue';
import MrWidgetPipelineContainer from '~/vue_merge_request_widget/components/mr_widget_pipeline_container.vue';
import MrWidgetApprovals from 'ee_else_ce/vue_merge_request_widget/components/approvals/approvals.vue';
import MrWidgetMigrateJenkins from '~/vue_merge_request_widget/components/mr_widget_migrate_jenkins.vue';
import MrWidgetAutoMergeEnabled from '~/vue_merge_request_widget/components/states/mr_widget_auto_merge_enabled.vue';
import MergeChecks from '~/vue_merge_request_widget/components/merge_checks.vue';
import ReadyToMerge from '~/vue_merge_request_widget/components/states/ready_to_merge.vue';
import Loading from '~/vue_merge_request_widget/components/loading.vue';
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
    MrWidgetAlertMessage,
    MrWidgetSuggestPipeline,
    MrWidgetMigrateJenkins,
    MrWidgetPipelineContainer,
    MrWidgetApprovals,
    MrWidgetAutoMergeEnabled,
    Loading,
    MergeChecks,
    ReadyToMerge,
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
  <div v-if="!loading" id="widget-state" class="mr-state-widget gl-mt-5">
    <header v-if="shouldRenderCollaborationStatus" class="mr-section-container gl-overflow-hidden">
      <mr-widget-alert-message type="info">
        {{ s__('mrWidget|Members who can merge are allowed to add commits.') }}
      </mr-widget-alert-message>
    </header>
    <mr-widget-suggest-pipeline
      v-if="shouldSuggestPipelines"
      class="mr-section-container"
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
    <widget-container v-if="mr" :mr="mr" />
    <div class="mr-section-container">
      <template v-if="hasAlerts">
        <mr-widget-alert-message
          v-if="hasMergeError"
          type="danger"
          dismissible
          data-testid="merge-error"
          class="mr-widget-section"
        >
          <span v-safe-html="mergeError"></span>
        </mr-widget-alert-message>
        <mr-widget-alert-message
          v-if="showMergePipelineForkWarning"
          type="warning"
          :help-path="mr.mergeRequestPipelinesHelpPath"
          class="mr-widget-section"
          data-testid="merge-pipeline-fork-warning"
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
      </template>
      <blocking-merge-requests-report class="gl-border-b" :mr="mr" />

      <div class="mr-widget-section">
        <template v-if="mergeBlockedComponentVisible">
          <mr-widget-auto-merge-enabled
            v-if="autoMergeEnabled"
            :mr="mr"
            :service="service"
            class="gl-border-b"
          />
          <merge-checks :mr="mr" :service="service" />
        </template>
        <component :is="componentName" v-else :mr="mr" :service="service" />
        <ready-to-merge v-if="mr.commitsCount" :mr="mr" :service="service" />
      </div>
    </div>
    <mr-widget-pipeline-container
      v-if="shouldRenderMergedPipeline"
      class="js-post-merge-pipeline"
      data-testid="merged-pipeline-container"
      :mr="mr"
      is-post-merge
    />
  </div>
  <loading v-else />
</template>
