<script>
import { GlEmptyState, GlButton } from '@gitlab/ui';
import { joinPaths, visitUrl, setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import { isGroup } from 'ee/security_orchestration/components/utils';
import {
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  GRAPHQL_ERROR_MESSAGE,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
  ACTIONS_LABEL,
  ADD_ACTION_LABEL,
} from '../constants';
import EditorLayout from '../editor_layout.vue';
import DimDisableContainer from '../dim_disable_container.vue';
import { assignSecurityPolicyProject, modifyPolicy, parseError } from '../utils';
import RuleSection from './rule/rule_section.vue';
import ScanAction from './action/scan_action.vue';
import ActionSection from './action/action_section.vue';
import OverloadWarningModal from './overload_warning_modal.vue';
import {
  buildScannerAction,
  buildDefaultPipeLineRule,
  createPolicyObject,
  DEFAULT_SCAN_EXECUTION_POLICY,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  fromYaml,
  policyToYaml,
} from './lib';
import {
  DEFAULT_SCANNER,
  ADD_CONDITION_LABEL,
  CONDITIONS_LABEL,
  ERROR_MESSAGE_MAP,
  CUSTOM_ACTION_KEY,
  SCAN_EXECUTION_ACTIONS_LISTBOX_ITEMS,
  SCAN_EXECUTION_RULES_SCHEDULE_KEY,
  EXECUTE_YAML_ACTION,
  PROJECTS_COUNT_PERFORMANCE_LIMIT,
} from './constants';

export default {
  ACTION: 'actions',
  RULE: 'rules',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  SCAN_EXECUTION_ACTIONS_LISTBOX_ITEMS,
  i18n: {
    ACTIONS_LABEL,
    ADD_ACTION_LABEL,
    ADD_CONDITION_LABEL,
    CONDITIONS_LABEL,
    PARSING_ERROR_MESSAGE,
    filterHeaderText: s__('SecurityOrchestration|Choose an action'),
    buttonText: s__('SecurityOrchestration|Add new action'),
    createMergeRequest: __('Configure with a merge request'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Scan execution policies can only be created by project owners.',
    ),
  },
  apollo: {
    projectsCount: {
      query: getGroupProjectsCount,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        return data.group?.projects?.count || 0;
      },
      skip() {
        return !isGroup(this.namespaceType) || !this.hasScheduledRule;
      },
      error() {
        this.projectsCount = 0;
      },
    },
  },
  components: {
    ScanFilterSelector,
    ActionSection,
    DimDisableContainer,
    GlButton,
    GlEmptyState,
    ScanAction,
    EditorLayout,
    OverloadWarningModal,
    RuleSection,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespacePath',
    'namespaceType',
    'scanPolicyDocumentationPath',
    'customCiToggleEnabled',
  ],
  props: {
    assignedPolicyProject: {
      type: Object,
      required: true,
    },
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const newPolicyYaml = isGroup(this.namespaceType)
      ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE
      : DEFAULT_SCAN_EXECUTION_POLICY;

    const yamlEditorValue = this.existingPolicy ? policyToYaml(this.existingPolicy) : newPolicyYaml;

    const { policy, hasParsingError } = createPolicyObject(yamlEditorValue);

    const parsingError = hasParsingError ? this.$options.i18n.PARSING_ERROR_MESSAGE : '';

    return {
      errorSources: [],
      projectsCount: 0,
      showPerformanceWarningModal: false,
      dismissPerformanceWarningModal: false,
      isCreatingMR: false,
      isRemovingPolicy: false,
      newlyCreatedPolicyProject: null,
      policy,
      hasParsingError,
      parsingError,
      yamlEditorValue,
      mode: EDITOR_MODE_RULE,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-execution-policy-editor',
      ),
    };
  },
  computed: {
    projectsPerformanceLimitReached() {
      return this.projectsCount > PROJECTS_COUNT_PERFORMANCE_LIMIT;
    },
    hasScheduledRule() {
      return this.policy?.rules?.some(({ type }) => type === SCAN_EXECUTION_RULES_SCHEDULE_KEY);
    },
    hasPerformanceRisk() {
      return (
        this.projectsPerformanceLimitReached && this.hasScheduledRule && isGroup(this.namespaceType)
      );
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    showActionSection() {
      return this.glFeatures.compliancePipelineInPolicies && this.customCiToggleEnabled;
    },
  },
  methods: {
    addAction(action) {
      const payload =
        this.showActionSection && action === EXECUTE_YAML_ACTION
          ? { scanner: CUSTOM_ACTION_KEY }
          : { scanner: DEFAULT_SCANNER };

      this.policy.actions.push(buildScannerAction(payload));
      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      this.policy.rules.push(buildDefaultPipeLineRule());
      this.updateYamlEditorValue(this.policy);
    },
    cancelPolicySubmit() {
      this.showPerformanceWarningModal = false;
    },
    confirmPolicySubmit() {
      this.showPerformanceWarningModal = false;
      this.dismissPerformanceWarningModal = true;
      this.handleModifyPolicy();
    },
    removeActionOrRule(type, index) {
      this.policy[type].splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateActionOrRule(type, index, values) {
      this.policy[type].splice(index, 1, values);
      this.updateYamlEditorValue(this.policy);
    },
    changeEditorMode(mode) {
      this.mode = mode;
    },
    handleError(error) {
      // Emit error for alert
      if (error.message.toLowerCase().includes('graphql')) {
        this.$emit('error', GRAPHQL_ERROR_MESSAGE);
      } else {
        this.$emit('error', error.message);
      }

      // Process error to pass to specific component
      this.errorSources = parseError(error);
    },
    handleActionBuilderParsingError(key) {
      this.hasParsingError = true;
      this.parsingError = ERROR_MESSAGE_MAP[key] || PARSING_ERROR_MESSAGE;
    },
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    async getSecurityPolicyProject() {
      if (!this.newlyCreatedPolicyProject && !this.assignedPolicyProject.fullPath) {
        this.newlyCreatedPolicyProject = await assignSecurityPolicyProject(this.namespacePath);
      }

      return this.newlyCreatedPolicyProject || this.assignedPolicyProject;
    },
    async handleModifyPolicy(act) {
      if (this.hasPerformanceRisk && !this.dismissPerformanceWarningModal) {
        this.showPerformanceWarningModal = true;
        return;
      }

      const action =
        act ||
        (this.isEditing
          ? this.$options.SECURITY_POLICY_ACTIONS.REPLACE
          : this.$options.SECURITY_POLICY_ACTIONS.APPEND);

      this.$emit('error', '');
      this.setLoadingFlag(action, true);

      try {
        const assignedPolicyProject = await this.getSecurityPolicyProject();
        const mergeRequest = await modifyPolicy({
          action,
          assignedPolicyProject,
          name: this.originalName || fromYaml({ manifest: this.yamlEditorValue })?.name,
          namespacePath: this.namespacePath,
          yamlEditorValue: this.yamlEditorValue,
        });

        this.redirectToMergeRequest({ mergeRequest, assignedPolicyProject });
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(action, false);
      }
    },
    setLoadingFlag(action, val) {
      if (action === SECURITY_POLICY_ACTIONS.REMOVE) {
        this.isRemovingPolicy = val;
      } else {
        this.isCreatingMR = val;
      }
    },
    redirectToMergeRequest({ mergeRequest, assignedPolicyProject }) {
      visitUrl(
        joinPaths(
          gon.relative_url_root || '/',
          assignedPolicyProject.fullPath,
          '/-/merge_requests',
          mergeRequest.id,
        ),
      );
    },
    updateYaml(manifest) {
      const { policy, hasParsingError } = createPolicyObject(manifest);

      this.yamlEditorValue = manifest;
      this.hasParsingError = hasParsingError;
      this.parsingError = hasParsingError ? this.$options.i18n.PARSING_ERROR_MESSAGE : '';
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(policy);
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :custom-save-button-text="$options.i18n.createMergeRequest"
    :has-parsing-error="hasParsingError"
    :is-editing="isEditing"
    :is-removing-policy="isRemovingPolicy"
    :is-updating-policy="isCreatingMR"
    :parsing-error="parsingError"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy()"
    @remove-property="handleRemoveProperty"
    @update-property="handleUpdateProperty"
    @update-yaml="updateYaml"
    @update-editor-mode="changeEditorMode"
  >
    <template #rules>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <rule-section
          v-for="(rule, index) in policy.rules"
          :key="rule.id"
          :data-testid="`rule-${index}`"
          class="gl-mb-4"
          :init-rule="rule"
          :rule-index="index"
          @changed="updateActionOrRule($options.RULE, index, $event)"
          @remove="removeActionOrRule($options.RULE, index)"
        />

        <div class="gl-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5">
          <gl-button variant="link" data-testid="add-rule" @click="addRule">
            {{ $options.i18n.ADD_CONDITION_LABEL }}
          </gl-button>
        </div>
      </dim-disable-container>
    </template>

    <template #actions-first>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <template v-if="showActionSection">
          <action-section
            v-for="(action, index) in policy.actions"
            :key="action.id"
            :data-testid="`action-${index}`"
            :action-index="index"
            :init-action="action"
            :error-sources="errorSources"
            @changed="updateActionOrRule($options.ACTION, index, $event)"
            @remove="removeActionOrRule($options.ACTION, index)"
            @parsing-error="handleActionBuilderParsingError"
          />

          <scan-filter-selector
            class="gl-w-full"
            :button-text="$options.i18n.buttonText"
            :header="$options.i18n.filterHeaderText"
            :filters="$options.SCAN_EXECUTION_ACTIONS_LISTBOX_ITEMS"
            @select="addAction"
          />
        </template>

        <template v-else>
          <scan-action
            v-for="(action, index) in policy.actions"
            :key="action.id"
            :data-testid="`action-${index}`"
            class="gl-mb-4"
            :init-action="action"
            :action-index="index"
            :error-sources="errorSources"
            @changed="updateActionOrRule($options.ACTION, index, $event)"
            @remove="removeActionOrRule($options.ACTION, index)"
            @parsing-error="handleActionBuilderParsingError"
          />

          <div class="gl-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5">
            <gl-button variant="link" data-testid="add-action" icon="plus" @click="addAction">
              {{ $options.i18n.ADD_ACTION_LABEL }}
            </gl-button>
          </div>
        </template>
      </dim-disable-container>
    </template>

    <template #modal>
      <overload-warning-modal
        :visible="showPerformanceWarningModal"
        @cancel-submit="cancelPolicySubmit"
        @confirm-submit="confirmPolicySubmit"
      />
    </template>
  </editor-layout>

  <gl-empty-state
    v-else
    :description="$options.i18n.notOwnerDescription"
    :primary-button-link="documentationPath"
    :primary-button-text="$options.i18n.notOwnerButtonText"
    :svg-path="policyEditorEmptyStateSvgPath"
    :svg-height="null"
    title=""
  />
</template>
