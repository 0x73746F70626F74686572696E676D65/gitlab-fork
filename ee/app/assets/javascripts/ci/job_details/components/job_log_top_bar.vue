<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import CeJobLogTopBar from '~/ci/job_details/components/job_log_top_bar.vue';
import RootCauseAnalysis from './sidebar/root_cause_analysis/root_cause_analysis_app.vue';

export default {
  components: {
    CeJobLogTopBar,
    GlButton,
    RootCauseAnalysis,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['aiRootCauseAnalysisAvailable'],
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
      return this.glFeatures.aiBuildFailureCause && this.aiRootCauseAnalysisAvailable;
    },
    jobFailed() {
      const { status } = this.job;

      const failedGroups = ['failed', 'failed-with-warnings'];

      return failedGroups.includes(status.group);
    },
    jobId() {
      return convertToGraphQLId(TYPENAME_CI_BUILD, this.job.id);
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
          class="gl-mr-2"
          data-testid="rca-button"
          @click="toggleDrawer"
        >
          {{ s__('Jobs|Troubleshoot') }}
        </gl-button>
      </template>
    </ce-job-log-top-bar>
  </div>
</template>
