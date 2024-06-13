<script>
import { GlDrawer, GlIcon, GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { joinPaths } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import {
  FAIL_STATUS,
  STANDARDS_ADHERENCE_CHECK_DESCRIPTIONS,
  STANDARDS_ADHERENCE_CHECK_FAILURE_REASONS,
  STANDARDS_ADHERENCE_CHECK_SUCCESS_REASONS,
  STANDARDS_ADHERENCE_CHECK_MR_FIX_TITLE,
  STANDARDS_ADHERENCE_CHECK_MR_FIX_FEATURES,
  STANDARDS_ADHERENCE_CHECK_LABELS,
  STANDARDS_ADHERENCE_CHECK_MR_FIX_LEARN_MORE_DOCS_LINKS,
} from './constants';

export default {
  name: 'FixSuggestionsSidebar',
  components: {
    GlDrawer,
    GlIcon,
    GlButton,
    GlLink,
    FrameworkBadge,
    GlSprintf,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    showDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
    adherence: {
      type: Object,
      required: true,
    },
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    project() {
      return this.adherence.project;
    },
    projectMRSettingsPath() {
      return joinPaths(this.project.webUrl, '-', 'settings', 'merge_requests');
    },
    isFailedStatus() {
      return this.adherence.status === FAIL_STATUS;
    },
    adherenceCheckName() {
      return STANDARDS_ADHERENCE_CHECK_LABELS[this.adherence.checkName];
    },
    adherenceCheckDescription() {
      return STANDARDS_ADHERENCE_CHECK_DESCRIPTIONS[this.adherence.checkName];
    },
    adherenceCheckFailureReason() {
      return STANDARDS_ADHERENCE_CHECK_FAILURE_REASONS[this.adherence.checkName];
    },
    adherenceCheckSuccessReason() {
      return STANDARDS_ADHERENCE_CHECK_SUCCESS_REASONS[this.adherence.checkName];
    },
    adherenceCheckLearnMoreLink() {
      return STANDARDS_ADHERENCE_CHECK_MR_FIX_LEARN_MORE_DOCS_LINKS[this.adherence.checkName];
    },
    projectFrameworksText() {
      return sprintf(
        s__(
          'ComplianceStandardsAdherence|Other compliance frameworks applied to %{linkStart}%{projectName}%{linkEnd}',
        ),
        { projectName: this.project.name },
      );
    },
  },
  standardsAdherenceCheckMRFixTitle: STANDARDS_ADHERENCE_CHECK_MR_FIX_TITLE,
  standardsAdherenceCheckMRFixes: STANDARDS_ADHERENCE_CHECK_MR_FIX_FEATURES,
  projectMRSettingsDocsPath: helpPagePath('user/project/merge_requests/approvals/rules'),
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="showDrawer"
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template #title>
      <div>
        <h2 class="gl-mt-0" data-testid="sidebar-title">{{ adherenceCheckName }}</h2>
        <div>
          <span v-if="isFailedStatus" class="gl-text-red-500 gl-font-bold">
            <gl-icon name="status_failed" /> {{ __('Fail') }}
          </span>
          <span v-else class="gl-text-green-500 gl-font-bold">
            <gl-icon name="status_success" /> {{ __('Success') }}
          </span>

          <gl-link class="gl-mx-3" :href="project.webUrl"> {{ project.name }} </gl-link>
        </div>
      </div>
    </template>

    <template #default>
      <div>
        <h3 data-testid="sidebar-requirement-title" class="gl-mt-0">
          {{ s__('ComplianceStandardsAdherence|Requirement') }}
        </h3>
        <span data-testid="sidebar-requirement-content">{{ adherenceCheckDescription }}</span>
      </div>

      <div v-if="isFailedStatus">
        <h3 data-testid="sidebar-failure-title" class="gl-mt-0">
          {{ s__('ComplianceStandardsAdherence|Failure reason') }}
        </h3>
        <span data-testid="sidebar-failure-content">{{ adherenceCheckFailureReason }}</span>
      </div>
      <div v-else>
        <h3 data-testid="sidebar-success-title" class="gl-mt-0">
          {{ s__('ComplianceStandardsAdherence|Success reason') }}
        </h3>
        <span data-testid="sidebar-success-content">{{ adherenceCheckSuccessReason }}</span>
      </div>

      <div v-if="isFailedStatus" data-testid="sidebar-how-to-fix">
        <div>
          <h3 class="gl-mt-0">{{ s__('ComplianceStandardsAdherence|How to fix') }}</h3>
        </div>
        <div class="gl-my-5">
          {{ $options.standardsAdherenceCheckMRFixTitle }}
        </div>
        <div
          v-for="fix in $options.standardsAdherenceCheckMRFixes"
          :key="fix.title"
          class="gl-mb-4"
        >
          <div class="gl-mb-4 gl-font-bold">{{ fix.title }}</div>
          <div class="gl-mb-4">{{ fix.description }}</div>
          <gl-button
            class="gl-my-3"
            size="small"
            category="secondary"
            variant="confirm"
            :href="projectMRSettingsPath"
            data-testid="sidebar-mr-settings-button"
          >
            {{ __('Manage rules') }}
          </gl-button>
          <gl-button
            size="small"
            :href="adherenceCheckLearnMoreLink"
            data-testid="sidebar-mr-settings-learn-more-button"
          >
            {{ __('Learn more') }}
          </gl-button>
        </div>
      </div>
      <div v-if="project.complianceFrameworks.nodes.length">
        <h3 class="gl-mt-0 gl-font-lg" data-testid="sidebar-frameworks-title">
          {{ s__('ComplianceStandardsAdherence|All attached frameworks') }}
        </h3>

        <div data-testid="sidebar-frameworks-content">
          <gl-sprintf :message="projectFrameworksText">
            <template #link="{ content }">
              <gl-link :href="project.webUrl">
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </div>
        <span v-for="framework in project.complianceFrameworks.nodes" :key="framework.id">
          <framework-badge :framework="framework" show-edit class="gl-display-inline" />
        </span>
      </div>
    </template>
  </gl-drawer>
</template>
