<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import CeJobLogTopBar from '~/ci/job_details/components/job_log_top_bar.vue';
import { helpCenterState } from '~/super_sidebar/constants';
import RootCauseAnalysis from './sidebar/root_cause_analysis/root_cause_analysis_app.vue';

export default {
  components: {
    CeJobLogTopBar,
    GlButton,
    RootCauseAnalysis,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['aiRootCauseAnalysisAvailable', 'duoFeaturesEnabled', 'jobGid'],
  props: {
    size: {
      type: Number,
      required: true,
    },
    rawPath: {
      type: String,
      required: false,
      default: null,
    },
    isScrollTopDisabled: {
      type: Boolean,
      required: true,
    },
    isScrollBottomDisabled: {
      type: Boolean,
      required: true,
    },
    isScrollingDown: {
      type: Boolean,
      required: true,
    },
    isJobLogSizeVisible: {
      type: Boolean,
      required: true,
    },
    isComplete: {
      type: Boolean,
      required: true,
    },
    jobLog: {
      type: Array,
      required: true,
    },
    fullScreenModeAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullScreenEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isRootCauseDrawerShown: false,
    };
  },
  computed: {
    rootCauseAnalysisIsAvailable() {
      return (
        this.glFeatures.aiBuildFailureCause &&
        this.aiRootCauseAnalysisAvailable &&
        this.duoFeaturesEnabled &&
        !this.glFeatures.rootCauseAnalysisDuo
      );
    },
    rootCauseAnalysisDuoIsAvailable() {
      return (
        this.glFeatures.aiBuildFailureCause &&
        this.aiRootCauseAnalysisAvailable &&
        this.duoFeaturesEnabled &&
        this.glFeatures.rootCauseAnalysisDuo
      );
    },
    jobFailed() {
      const { status } = this.job;

      const failedGroups = ['failed', 'failed-with-warnings'];

      return failedGroups.includes(status.group);
    },
    jobId() {
      return convertToGraphQLId(TYPENAME_CI_BUILD, this.job.id);
    },
    duoDrawerOpen() {
      return helpCenterState.showTanukiBotChatDrawer;
    },
    ...mapState(['job', 'isLoading']),
  },
  methods: {
    toggleDrawer() {
      this.isRootCauseDrawerShown = !this.isRootCauseDrawerShown;
    },
    handleScrollTop() {
      this.$emit('scrollJobLogTop');
    },
    handleScrollBottom() {
      this.$emit('scrollJobLogBottom');
    },
    handleSearchResults(searchResults) {
      this.$emit('searchResults', searchResults);
    },
    handleFullscreen() {
      this.$emit('enterFullscreen');
    },
    handleExitFullscreen() {
      this.$emit('exitFullscreen');
    },
    callDuo() {
      helpCenterState.showTanukiBotChatDrawer = true;

      this.$apollo
        .mutate({
          mutation: chatMutation,
          variables: {
            question: '/rca',
            resourceId: this.jobGid,
          },
        })
        .catch((error) => {
          createAlert({
            message: s__('AI|An error occurred while troubleshooting the failed job.'),
            captureError: true,
            error,
          });
        });
    },
  },
};
</script>
<template>
  <div class="gl-display-contents">
    <root-cause-analysis
      v-if="rootCauseAnalysisIsAvailable"
      :is-shown="isRootCauseDrawerShown"
      :job-id="jobId || ''"
      :is-job-loading="isLoading"
      @close="toggleDrawer"
    />
    <ce-job-log-top-bar
      :size="size"
      :raw-path="rawPath"
      :is-scroll-top-disabled="isScrollTopDisabled"
      :is-scroll-bottom-disabled="isScrollBottomDisabled"
      :is-scrolling-down="isScrollingDown"
      :is-job-log-size-visible="isJobLogSizeVisible"
      :is-complete="isComplete"
      :job-log="jobLog"
      :full-screen-mode-available="fullScreenModeAvailable"
      :full-screen-enabled="fullScreenEnabled"
      v-bind="$attrs"
      @scrollJobLogTop="handleScrollTop"
      @scrollJobLogBottom="handleScrollBottom"
      @searchResults="handleSearchResults"
      @enterFullscreen="handleFullscreen"
      @exitFullscreen="handleExitFullscreen"
    >
      <template #controllers>
        <gl-button
          v-if="rootCauseAnalysisIsAvailable && jobFailed"
          icon="tanuki-ai"
          class="gl-mr-3"
          data-testid="rca-button"
          @click="toggleDrawer"
        >
          {{ s__('Jobs|Troubleshoot') }}
        </gl-button>
        <gl-button
          v-if="rootCauseAnalysisDuoIsAvailable && jobFailed"
          :disabled="duoDrawerOpen"
          icon="tanuki-ai"
          class="gl-mr-3"
          data-testid="rca-duo-button"
          @click="callDuo"
        >
          {{ s__('Jobs|Troubleshoot') }}
        </gl-button>
      </template>
    </ce-job-log-top-bar>
  </div>
</template>
