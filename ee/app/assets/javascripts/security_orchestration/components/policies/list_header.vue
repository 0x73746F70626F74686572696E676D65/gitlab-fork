<script>
import { GlAlert, GlButton, GlIcon, GlSprintf } from '@gitlab/ui';
import { joinPaths } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { NEW_POLICY_BUTTON_TEXT } from '../constants';
import BreakingChangesBanner from './banners/breaking_changes_banner.vue';
import ExperimentFeaturesBanner from './banners/experiment_features_banner.vue';
import InvalidPoliciesBanner from './banners/invalid_policies_banner.vue';
import ProjectModal from './project_modal.vue';

export default {
  BANNER_STORAGE_KEY: 'security_policies_scan_result_name_change',
  components: {
    BreakingChangesBanner,
    ExperimentFeaturesBanner,
    GlAlert,
    GlButton,
    GlIcon,
    GlSprintf,
    InvalidPoliciesBanner,
    ProjectModal,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'assignedPolicyProject',
    'disableSecurityPolicyProject',
    'disableScanPolicyUpdate',
    'documentationPath',
    'newPolicyPath',
    'namespaceType',
  ],
  props: {
    hasInvalidPolicies: {
      type: Boolean,
      required: true,
    },
  },
  i18n: {
    title: s__('SecurityOrchestration|Policies'),
    subtitle: {
      [NAMESPACE_TYPES.GROUP]: s__(
        'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for this group.',
      ),
      [NAMESPACE_TYPES.PROJECT]: s__(
        'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for this project.',
      ),
    },
    newPolicyButtonText: NEW_POLICY_BUTTON_TEXT,
    editPolicyProjectButtonText: s__('SecurityOrchestration|Edit policy project'),
    viewPolicyProjectButtonText: s__('SecurityOrchestration|View policy project'),
  },
  data() {
    return {
      projectIsBeingLinked: false,
      showAlert: false,
      alertVariant: '',
      alertText: '',
      modalVisible: false,
    };
  },
  computed: {
    feedbackBannerEnabled() {
      return this.glFeatures.compliancePipelineInPolicies;
    },
    hasAssignedPolicyProject() {
      return Boolean(this.assignedPolicyProject?.id);
    },
    securityPolicyProjectPath() {
      return joinPaths('/', this.assignedPolicyProject?.full_path);
    },
  },
  methods: {
    updateAlertText({ text, variant, hasPolicyProject }) {
      this.projectIsBeingLinked = false;

      if (text) {
        this.showAlert = true;
        this.alertVariant = variant;
        this.alertText = text;
      }
      this.$emit('update-policy-list', { hasPolicyProject, shouldUpdatePolicyList: true });
    },
    isUpdatingProject() {
      this.projectIsBeingLinked = true;
      this.showAlert = false;
      this.alertVariant = '';
      this.alertText = '';
    },
    dismissAlert() {
      this.showAlert = false;
    },
    showNewPolicyModal() {
      this.modalVisible = true;
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showAlert"
      class="gl-mt-3"
      :dismissible="true"
      :variant="alertVariant"
      data-testid="error-alert"
      @dismiss="dismissAlert"
    >
      {{ alertText }}
    </gl-alert>
    <header class="gl-my-6 gl-display-flex gl-flex-direction-column">
      <div class="gl-display-flex gl-align-items-flex-start">
        <div class="gl-flex-grow-1 gl-my-0">
          <h2 class="gl-mt-0">
            {{ $options.i18n.title }}
          </h2>
          <p data-testid="policies-subheader">
            <gl-sprintf :message="$options.i18n.subtitle[namespaceType]">
              <template #link="{ content }">
                <gl-button
                  class="gl-pb-1!"
                  variant="link"
                  :href="documentationPath"
                  target="_blank"
                >
                  {{ content }}
                </gl-button>
              </template>
            </gl-sprintf>
          </p>
        </div>
        <gl-button
          v-if="!disableSecurityPolicyProject"
          data-testid="edit-project-policy-button"
          class="gl-mr-4"
          :loading="projectIsBeingLinked"
          @click="showNewPolicyModal"
        >
          {{ $options.i18n.editPolicyProjectButtonText }}
        </gl-button>
        <gl-button
          v-else-if="hasAssignedPolicyProject"
          data-testid="view-project-policy-button"
          class="gl-mr-3"
          target="_blank"
          :href="securityPolicyProjectPath"
        >
          <gl-icon name="external-link" />
          {{ $options.i18n.viewPolicyProjectButtonText }}
        </gl-button>
        <gl-button
          v-if="!disableScanPolicyUpdate"
          data-testid="new-policy-button"
          variant="confirm"
          :href="newPolicyPath"
        >
          {{ $options.i18n.newPolicyButtonText }}
        </gl-button>
      </div>

      <experiment-features-banner v-if="feedbackBannerEnabled" />

      <project-modal
        :visible="modalVisible"
        @close="modalVisible = false"
        @project-updated="updateAlertText"
        @updating-project="isUpdatingProject"
      />
    </header>

    <breaking-changes-banner class="gl-mt-3 gl-mb-6" />

    <invalid-policies-banner v-if="hasInvalidPolicies" />
  </div>
</template>
