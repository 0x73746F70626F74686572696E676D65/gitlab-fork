<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { vulnerabilityModalMixin } from 'ee/vue_shared/security_reports/mixins/vulnerability_modal_mixin';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import { VULNERABILITY_MODAL_ID } from 'ee/vue_shared/security_reports/components/constants';
import { setupStore } from '../../store';
import VulnerabilityReportLayout from '../shared/vulnerability_report_layout.vue';
import Filters from './filters.vue';
import LoadingError from './loading_error.vue';
import SecurityDashboardTable from './security_dashboard_table.vue';

export default {
  components: {
    Filters,
    VulnerabilityFindingModal,
    VulnerabilityReportLayout,
    SecurityDashboardTable,
    LoadingError,
  },
  mixins: [glFeatureFlagMixin(), vulnerabilityModalMixin('vulnerabilities')],
  inject: ['pipeline', 'projectId', 'projectFullPath'],
  props: {
    vulnerabilitiesEndpoint: {
      type: String,
      required: true,
    },
    pipelineId: {
      type: Number,
      required: false,
      default: null,
    },
    securityReportSummary: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    loadingErrorIllustrations: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      shouldShowModal: false,
    };
  },
  computed: {
    ...mapState('vulnerabilities', [
      'modal',
      'pageInfo',
      'loadingVulnerabilitiesErrorCode',
      'isCreatingIssue',
      'isDismissingVulnerability',
      'isCreatingMergeRequest',
    ]),
    ...mapState('pipelineJobs', { projectUniqueId: 'projectId' }),
    ...mapState('filters', ['filters']),
    ...mapGetters('vulnerabilities', ['loadingVulnerabilitiesFailedWithRecognizedErrorCode']),
    vulnerability() {
      return this.modal.vulnerability;
    },
  },
  created() {
    setupStore(this.$store);
    this.setSourceBranch(this.pipeline.sourceBranch);
    this.setPipelineJobsPath(this.pipeline.jobsPath);
    this.setProjectId(this.projectId);
    this.setPipelineId(this.pipelineId);
    this.setVulnerabilitiesEndpoint(this.vulnerabilitiesEndpoint);
    this.fetchPipelineJobs();

    // the click on a report row will trigger the BV_SHOW_MODAL event
    this.$root.$on(BV_SHOW_MODAL, this.showModal);
  },
  beforeDestroy() {
    this.$root.$off(BV_SHOW_MODAL, this.showModal);
  },
  methods: {
    ...mapActions('vulnerabilities', [
      'setSourceBranch',
      'closeDismissalCommentBox',
      'createIssue',
      'createMergeRequest',
      'openDismissalCommentBox',
      'setPipelineId',
      'setVulnerabilitiesEndpoint',
      'showDismissalDeleteButtons',
      'hideDismissalDeleteButtons',
      'downloadPatch',
      'reFetchVulnerabilitiesAfterDismissal',
    ]),
    ...mapActions('pipelineJobs', ['setPipelineJobsPath', 'setProjectId', 'fetchPipelineJobs']),
    ...mapActions('filters', ['lockFilter', 'setHideDismissedToggleInitialState']),
    showModal(modalId) {
      if (modalId === VULNERABILITY_MODAL_ID) {
        this.shouldShowModal = true;
      }
    },
  },
};
</script>

<template>
  <section>
    <loading-error
      v-if="loadingVulnerabilitiesFailedWithRecognizedErrorCode"
      :error-code="loadingVulnerabilitiesErrorCode"
      :illustrations="loadingErrorIllustrations"
    />
    <template v-else>
      <vulnerability-report-layout>
        <template #header>
          <filters />
        </template>

        <security-dashboard-table>
          <template #empty-state>
            <slot name="empty-state"></slot>
          </template>
        </security-dashboard-table>
      </vulnerability-report-layout>

      <vulnerability-finding-modal
        v-if="shouldShowModal"
        :finding-uuid="vulnerability.uuid"
        :pipeline-iid="pipeline.iid"
        :project-full-path="projectFullPath"
        @dismissed="reFetchVulnerabilitiesAfterDismissal({ vulnerability })"
        @detected="reFetchVulnerabilitiesAfterDismissal({ vulnerability, showToast: false })"
        @hidden="shouldShowModal = false"
      />
    </template>
  </section>
</template>
