<script>
import jiraLogo from '@gitlab/svgs/dist/illustrations/logos/jira.svg?raw';
import {
  GlButton,
  GlFormCheckbox,
  GlSkeletonLoader,
  GlSprintf,
  GlIcon,
  GlLink,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { VULNERABILITY_MODAL_ID } from 'ee/vue_shared/security_reports/components/constants';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import convertReportType from 'ee/vue_shared/security_reports/store/utils/convert_report_type';
import getPrimaryIdentifier from 'ee/vue_shared/security_reports/store/utils/get_primary_identifier';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  getCreatedIssueForVulnerability,
  getDismissalTransitionForVulnerability,
} from 'ee/vue_shared/security_reports/components/helpers';
import VulnerabilityActionButtons from './vulnerability_action_buttons.vue';
import VulnerabilityIssueLink from './vulnerability_issue_link.vue';

export default {
  name: 'SecurityDashboardTableRow',
  components: {
    GlButton,
    GlFormCheckbox,
    GlSkeletonLoader,
    GlSprintf,
    GlIcon,
    GlLink,
    SeverityBadge,
    VulnerabilityActionButtons,
    VulnerabilityIssueLink,
  },
  directives: {
    SafeHtml,
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['canAdminVulnerability'],
  props: {
    vulnerability: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState('vulnerabilities', ['selectedVulnerabilities']),
    vulnerabilityIdentifier() {
      return getPrimaryIdentifier(this.vulnerability.identifiers, 'external_type');
    },
    vulnerabilityNamespace() {
      const { location } = this.vulnerability;
      return location && (location.image || location.file || location.path);
    },
    dismissalData() {
      return getDismissalTransitionForVulnerability(this.vulnerability);
    },
    dismissalComment() {
      return this.dismissalData?.comment;
    },
    issueData() {
      return getCreatedIssueForVulnerability(this.vulnerability);
    },
    hasIssue() {
      return Boolean(this.issueData || this.jiraIssueData);
    },
    hasJiraIssue() {
      return Boolean(this.jiraIssueData);
    },
    hasGitLabIssue() {
      return Boolean(this.issueData);
    },
    jiraIssueData() {
      const jiraIssue = this.vulnerability.external_issue_links?.find(
        (link) => link.external_issue_details?.external_tracker === 'jira',
      );

      if (!jiraIssue) {
        return null;
      }

      const {
        external_issue_details: {
          web_url: webUrl,
          references: { relative: title },
        },
      } = jiraIssue;

      return {
        webUrl,
        title,
      };
    },
    isJiraIssueCreationEnabled() {
      return Boolean(this.vulnerability.create_jira_issue_url);
    },
    canDismissVulnerability() {
      const path = this.vulnerability.create_vulnerability_feedback_dismissal_path;
      return Boolean(path);
    },
    canCreateIssue() {
      const {
        create_vulnerability_feedback_issue_path: createGitLabIssuePath,
        create_jira_issue_url: createJiraIssueUrl,
      } = this.vulnerability;

      if (createJiraIssueUrl && !this.hasJiraIssue) {
        return true;
      }

      if (createGitLabIssuePath && !this.hasGitLabIssue) {
        return true;
      }

      return false;
    },
    extraIdentifierCount() {
      const { identifiers } = this.vulnerability;

      if (!identifiers) {
        return 0;
      }

      return identifiers.length - 1;
    },
    isSelected() {
      return Boolean(this.selectedVulnerabilities[this.vulnerability.id]);
    },
    shouldShowExtraIdentifierCount() {
      return this.extraIdentifierCount > 0;
    },
    useConvertReportType() {
      return convertReportType(this.vulnerability.report_type);
    },
    vulnerabilityVendor() {
      return this.vulnerability.scanner?.vendor;
    },
  },
  methods: {
    ...mapActions('vulnerabilities', [
      'setModalData',
      'selectVulnerability',
      'deselectVulnerability',
    ]),
    toggleVulnerability() {
      if (this.isSelected) {
        return this.deselectVulnerability(this.vulnerability);
      }
      return this.selectVulnerability(this.vulnerability);
    },
    openModal(payload) {
      this.setModalData(payload);
      this.$root.$emit(BV_SHOW_MODAL, VULNERABILITY_MODAL_ID);
    },
  },
  jiraLogo,
};
</script>

<template>
  <div
    class="gl-responsive-table-row p-2"
    :class="{ dismissed: dismissalData, 'gl-bg-blue-50': isSelected }"
  >
    <div v-if="canAdminVulnerability" class="table-section section-5">
      <gl-form-checkbox
        :checked="isSelected"
        :inline="true"
        class="my-0 ml-1 mr-3"
        data-testid="security-finding-checkbox"
        :data-qa-finding-name="vulnerability.name"
        @change="toggleVulnerability"
      />
    </div>

    <div class="table-section section-15">
      <div class="table-mobile-header" role="rowheader">{{ s__('Reports|Severity') }}</div>
      <div class="table-mobile-content">
        <severity-badge
          v-if="vulnerability.severity"
          :severity="vulnerability.severity"
          class="text-right text-md-left"
        />
      </div>
    </div>

    <div class="table-section flex-grow-1">
      <div class="table-mobile-header" role="rowheader">{{ s__('Reports|Vulnerability') }}</div>
      <div
        class="table-mobile-content gl-whitespace-normal"
        data-testid="vulnerability-info-content"
      >
        <gl-skeleton-loader v-if="isLoading" :lines="2" />
        <template v-else>
          <gl-button
            ref="vulnerability-title"
            class="text-body gl-display-grid"
            button-text-classes="gl-text-left gl-whitespace-normal! gl-pr-4!"
            variant="link"
            data-testid="security-finding-name-button"
            :data-qa-status-description="vulnerability.name"
            @click="openModal({ vulnerability })"
            >{{ vulnerability.name }}</gl-button
          >
          <span v-if="dismissalData" data-testid="dismissal-label">
            <gl-icon v-if="dismissalComment" name="comment" class="text-warning" />
            <span class="text-uppercase">{{ s__('vulnerability|dismissed') }}</span>
          </span>
          <span
            v-if="isJiraIssueCreationEnabled && hasJiraIssue"
            class="gl-inline-flex gl-align-items-baseline"
          >
            <span
              v-safe-html="$options.jiraLogo"
              v-gl-tooltip
              :title="s__('SecurityReports|Jira Issue Created')"
              class="gl-align-self-end gl-mr-2"
              data-testid="jira-issue-icon"
            >
            </span>
            <gl-link
              :href="jiraIssueData.webUrl"
              target="_blank"
              class="vertical-align-middle"
              data-testid="jira-issue-link"
              >{{ jiraIssueData.title }}</gl-link
            >
          </span>
          <vulnerability-issue-link
            v-if="!isJiraIssueCreationEnabled && hasGitLabIssue"
            class="text-nowrap"
            :issue="issueData"
            :project-name="vulnerability.project.name"
          />

          <small v-if="vulnerabilityNamespace" class="gl-text-gray-500 gl-break-all">
            {{ vulnerabilityNamespace }}
          </small>
        </template>
      </div>
    </div>

    <div class="table-section gl-whitespace-normal section-15">
      <div class="table-mobile-header" role="rowheader">{{ s__('Reports|Identifier') }}</div>
      <div class="table-mobile-content">
        <div class="gl-text-overflow-ellipsis gl-overflow-hidden" :title="vulnerabilityIdentifier">
          {{ vulnerabilityIdentifier }}
        </div>
        <div v-if="shouldShowExtraIdentifierCount" class="gl-text-gray-300">
          <gl-sprintf :message="__('+ %{count} more')">
            <template #count>
              {{ extraIdentifierCount }}
            </template>
          </gl-sprintf>
        </div>
      </div>
    </div>

    <div class="table-section section-15">
      <div class="table-mobile-header" role="rowheader">{{ s__('Reports|Scanner') }}</div>
      <div class="table-mobile-content">
        <div class="text-capitalize">
          {{ useConvertReportType }}
        </div>
        <div v-if="vulnerabilityVendor" class="gl-text-gray-300" data-testid="vulnerability-vendor">
          {{ vulnerabilityVendor }}
        </div>
      </div>
    </div>

    <div class="table-section section-20">
      <div class="table-mobile-header" role="rowheader">{{ s__('Reports|Actions') }}</div>
      <div class="table-mobile-content action-buttons gl-flex justify-content-end">
        <vulnerability-action-buttons
          v-if="!isLoading"
          :vulnerability="vulnerability"
          :can-create-issue="canCreateIssue"
          :can-dismiss-vulnerability="canDismissVulnerability"
          :is-dismissed="Boolean(dismissalData)"
        />
      </div>
    </div>
  </div>
</template>
