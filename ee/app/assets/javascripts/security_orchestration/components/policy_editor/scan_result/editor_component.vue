<script>
import { isEmpty, uniqBy } from 'lodash';
import { GlAlert, GlEmptyState, GlButton } from '@gitlab/ui';
import { joinPaths, visitUrl, setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { isGroup, isProject } from 'ee/security_orchestration/components/utils';

import {
  ADD_ACTION_LABEL,
  BRANCHES_KEY,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  SECURITY_POLICY_ACTIONS,
  GRAPHQL_ERROR_MESSAGE,
  PARSING_ERROR_MESSAGE,
  ACTIONS_LABEL,
  ADD_RULE_LABEL,
  RULES_LABEL,
  MAX_ALLOWED_RULES_LENGTH,
} from '../constants';
import EditorLayout from '../editor_layout.vue';
import { assignSecurityPolicyProject, modifyPolicy } from '../utils';
import DimDisableContainer from '../dim_disable_container.vue';
import ScanFilterSelector from '../scan_filter_selector.vue';
import SettingsSection from './settings/settings_section.vue';
import ActionSection from './action/action_section.vue';
import ApproverAction from './action/approver_action.vue';
import RuleSection from './rule/rule_section.vue';
import FallbackSection from './fallback_section.vue';
import { CLOSED } from './constants';

import {
  ACTION_LISTBOX_ITEMS,
  buildAction,
  buildSettingsList,
  createPolicyObject,
  getInvalidBranches,
  getPolicyYaml,
  fromYaml,
  policyToYaml,
  approversOutOfSync,
  emptyBuildRule,
  invalidScanners,
  invalidSeverities,
  invalidVulnerabilitiesAllowed,
  invalidVulnerabilityStates,
  invalidVulnerabilityAge,
  invalidVulnerabilityAttributes,
  humanizeInvalidBranchesError,
  invalidBranchType,
  BOT_MESSAGE_TYPE,
  REQUIRE_APPROVAL_TYPE,
} from './lib';

export default {
  ACTION_LISTBOX_ITEMS,
  ADD_RULE_LABEL,
  RULES_LABEL,
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  i18n: {
    ADD_ACTION_LABEL,
    PARSING_ERROR_MESSAGE,
    buttonText: s__('SecurityOrchestration|Add new action'),
    createMergeRequest: __('Configure with a merge request'),
    filterHeaderText: s__('SecurityOrchestration|Choose an action'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Merge request approval policies can only be created by project owners.',
    ),
    settingsTitle: s__('ScanResultPolicy|Override project approval settings'),
    yamlPreview: s__('SecurityOrchestration|.yaml preview'),
    ACTIONS_LABEL,
    settingWarningTitle: s__(
      'SecurityOrchestration|Only overriding settings and bot message will take effect',
    ),
    settingWarningDescription: s__(
      "SecurityOrchestration|For any MR that matches this policy's rules, only the override project approval settings apply and bot message enabled. No additional approvals are required.",
    ),
    oldSettingWarningTitle: s__('SecurityOrchestration|Only overriding settings will take effect'),
    oldSettingWarningDescription: s__(
      "SecurityOrchestration|For any MR that matches this policy's rules, only the override project approval settings apply. No additional approvals are required.",
    ),
    settingErrorTitle: s__('SecurityOrchestration|Cannot create an empty policy'),
    settingErrorDescription: s__(
      "SecurityOrchestration|This policy doesn't contain any actions or override project approval settings. You cannot create an empty policy.",
    ),
  },
  components: {
    ActionSection,
    ApproverAction,
    DimDisableContainer,
    FallbackSection,
    GlAlert,
    GlButton,
    GlEmptyState,
    EditorLayout,
    RuleSection,
    ScanFilterSelector,
    SettingsSection,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespaceId',
    'namespacePath',
    'scanPolicyDocumentationPath',
    'scanResultPolicyApprovers',
    'namespaceType',
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
    const includeBotComment = this.glFeatures.approvalPolicyDisableBotComment;
    const includeFallback =
      this.glFeatures.mergeRequestApprovalPoliciesFallbackBehavior ||
      this.glFeatures.mergeRequestApprovalPoliciesFallbackBehaviorGroup;

    const newPolicyYaml = getPolicyYaml({
      includeBotComment,
      includeFallback,
      isGroup: isGroup(this.namespaceType),
    });

    const yamlEditorValue = this.existingPolicy ? policyToYaml(this.existingPolicy) : newPolicyYaml;

    const { policy, hasParsingError } = createPolicyObject(yamlEditorValue);

    return {
      errors: { action: [] },
      invalidBranches: [],
      isCreatingMR: false,
      isRemovingPolicy: false,
      newlyCreatedPolicyProject: null,
      policy,
      hasParsingError,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-result-policy-editor',
      ),
      mode: EDITOR_MODE_RULE,
      existingApprovers: this.scanResultPolicyApprovers,
      yamlEditorValue,
    };
  },
  computed: {
    actionsForRuleMode() {
      const actions = this.policy.actions || [];
      // If the yaml does not have a bot message action, then the bot message will be created as if
      // the bot message action exists and is enabled. Thus, we add it into the actions for rule
      // mode so the user can remove it
      const policiesWithBotMessageAction = uniqBy(
        [...actions, buildAction(BOT_MESSAGE_TYPE)],
        'type',
      );
      // If the bot message action is disabled, it should not appear in rule mode
      return policiesWithBotMessageAction.filter(
        (action) => action.type !== BOT_MESSAGE_TYPE || action.enabled,
      );
    },
    availableActionListboxItems() {
      const usedActionTypes = this.actionsForRuleMode.map((action) => action.type);
      return ACTION_LISTBOX_ITEMS.filter((item) => !usedActionTypes.includes(item.value));
    },
    disableUpdate() {
      return !this.hasParsingError && this.hasEmptyActions && this.hasEmptySettings;
    },
    fallbackBehaviorSetting() {
      return this.policy.fallback_behavior?.fail || CLOSED;
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    settings() {
      return buildSettingsList({ settings: this.policy.approval_settings });
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    policyActionName() {
      return this.isEditing
        ? this.$options.SECURITY_POLICY_ACTIONS.REPLACE
        : this.$options.SECURITY_POLICY_ACTIONS.APPEND;
    },
    isWithinLimit() {
      return this.policy.rules?.length < MAX_ALLOWED_RULES_LENGTH;
    },
    hasRequireApprovalAction() {
      return this.policy.actions?.some(({ type }) => type === REQUIRE_APPROVAL_TYPE);
    },
    hasEmptyActions() {
      return this.glFeatures.approvalPolicyDisableBotComment
        ? this.policy.actions?.every(({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled)
        : !this.policy.actions?.length;
    },
    hasEmptyRules() {
      return this.policy.rules?.length === 0 || this.policy.rules?.at(0)?.type === '';
    },
    hasEmptySettings() {
      return (
        isEmpty(this.policy.approval_settings) ||
        Object.values(this.policy.approval_settings).every((value) => {
          if (typeof value === 'boolean') {
            return !value;
          }
          return true;
        })
      );
    },
    hasDisabledBotMessageAction() {
      return this.policy.actions?.some(
        ({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled,
      );
    },
    isActiveRuleMode() {
      return this.mode === EDITOR_MODE_RULE && !this.hasParsingError;
    },
    allBranches() {
      return this.policy.rules.flatMap((rule) => rule.branches);
    },
    rulesHaveBranches() {
      return this.policy.rules.some(this.ruleHasBranchesProperty);
    },
    settingAlert() {
      if (this.hasEmptySettings && this.hasEmptyActions) {
        return {
          variant: 'danger',
          title: this.$options.i18n.settingErrorTitle,
          description: this.$options.i18n.settingErrorDescription,
        };
      }

      if (this.glFeatures.approvalPolicyDisableBotComment) {
        return {
          variant: 'warning',
          title: this.$options.i18n.settingWarningTitle,
          description: this.$options.i18n.settingWarningDescription,
        };
      }

      return {
        variant: 'warning',
        title: this.$options.i18n.oldSettingWarningTitle,
        description: this.$options.i18n.oldSettingWarningDescription,
      };
    },
    showBotMessageAction() {
      return this.isProject && this.glFeatures.approvalPolicyDisableBotComment;
    },
  },
  watch: {
    invalidBranches(branches) {
      if (branches.length > 0) {
        this.handleError(new Error(humanizeInvalidBranchesError([...branches])));
      } else {
        this.$emit('error', '');
      }
    },
  },
  methods: {
    ruleHasBranchesProperty(rule) {
      return BRANCHES_KEY in rule;
    },
    oldAddAction(type) {
      // TODO: Remove with the approvalPolicyDisableBotComment feature flag
      const newAction = buildAction(type);
      this.policy = {
        ...this.policy,
        actions: this.policy.actions ? [...this.policy.actions, newAction] : [newAction],
      };
      this.updateYamlEditorValue(this.policy);
    },
    oldRemoveAction(index) {
      // TODO: Remove with the approvalPolicyDisableBotComment feature flag
      const { actions, ...newPolicy } = this.policy;
      actions.splice(index, 1);
      this.policy = { ...newPolicy, ...(actions.length ? { actions } : {}) };
      this.updateYamlEditorValue(this.policy);
      this.updatePolicyApprovers({});
    },
    oldUpdateAction(actionIndex, values) {
      // TODO: Remove with the approvalPolicyDisableBotComment feature flag
      this.policy.actions.splice(actionIndex, 1, values);
      this.errors = {
        ...this.errors,
        action: [],
      };
      this.updateYamlEditorValue(this.policy);
    },
    addAction(type) {
      if (type === BOT_MESSAGE_TYPE && this.hasDisabledBotMessageAction) {
        // If the bot message action is in the yaml and is disabled, then we do not want to add
        // a new bot message action, but instead enable the existing one
        this.updateAction(buildAction(BOT_MESSAGE_TYPE));
      } else {
        const newAction = buildAction(type);
        this.policy = {
          ...this.policy,
          actions: this.policy.actions ? [...this.policy.actions, newAction] : [newAction],
        };
        this.updateYamlEditorValue(this.policy);
      }
    },
    removeApproverAction() {
      const { actions, ...newPolicy } = this.policy;
      const updatedActions = actions.filter((action) => action.type !== REQUIRE_APPROVAL_TYPE);
      this.policy = { ...newPolicy, ...(updatedActions.length ? { actions: updatedActions } : {}) };
      this.updateYamlEditorValue(this.policy);
      this.updatePolicyApprovers({});
    },
    updateAction(values) {
      const actionType = values.type;
      const actions = this.policy.actions || [];
      const indexOfActionToUpdate = actions.findIndex((a) => a.type === actionType);

      if (indexOfActionToUpdate >= 0) {
        actions.splice(indexOfActionToUpdate, 1, values);
      } else {
        actions.push(values);
      }

      this.policy.actions = actions;
      this.errors.action = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateSettings(values) {
      if (!this.policy.approval_settings) {
        this.policy = {
          ...this.policy,
          approval_settings: values,
        };
      } else {
        this.policy.approval_settings = values;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      this.policy.rules.push(emptyBuildRule());
      this.updateYamlEditorValue(this.policy);
    },
    removeRule(index) {
      this.policy.rules.splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateRule(ruleIndex, rule) {
      this.policy.rules.splice(ruleIndex, 1, rule);
      this.updateSettings(this.settings);
      this.updateYamlEditorValue(this.policy);
    },
    handleError(error) {
      if (this.isActiveRuleMode && error.cause?.length) {
        const ACTION_ERROR_FIELDS = ['approvers_ids'];
        const action = error.cause.filter((cause) => ACTION_ERROR_FIELDS.includes(cause.field));

        if (error.cause.some((cause) => !ACTION_ERROR_FIELDS.includes(cause.field))) {
          this.$emit('error', error.message);
        }

        if (action.length) {
          this.errors = { action };
        }
      } else if (error.message.toLowerCase().includes('graphql')) {
        this.$emit('error', GRAPHQL_ERROR_MESSAGE);
      } else {
        this.$emit('error', error.message);
      }
    },
    handleParsingError() {
      this.hasParsingError = true;
    },
    async getSecurityPolicyProject() {
      if (!this.newlyCreatedPolicyProject && !this.assignedPolicyProject.fullPath) {
        this.newlyCreatedPolicyProject = await assignSecurityPolicyProject(this.namespacePath);
      }

      return this.newlyCreatedPolicyProject || this.assignedPolicyProject;
    },
    async handleModifyPolicy(act) {
      const action = act || this.policyActionName;

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
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
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
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(policy);
    },
    async changeEditorMode(mode) {
      this.mode = mode;
      if (this.isActiveRuleMode) {
        this.hasParsingError = this.invalidForRuleMode();

        if (!this.hasEmptyRules && this.isProject && this.rulesHaveBranches) {
          this.invalidBranches = await getInvalidBranches({
            branches: this.allBranches,
            projectId: this.namespaceId,
          });
        }
      }
    },
    updatePolicyApprovers(values) {
      this.existingApprovers = values;
    },
    invalidForRuleMode() {
      const { actions, rules } = this.policy;
      const approvalAction = actions?.find((action) => action.type === REQUIRE_APPROVAL_TYPE);
      const invalidApprovers = approversOutOfSync(approvalAction, this.existingApprovers);

      return (
        invalidApprovers ||
        invalidScanners(rules) ||
        invalidSeverities(rules) ||
        invalidVulnerabilitiesAllowed(rules) ||
        invalidVulnerabilityStates(rules) ||
        invalidBranchType(rules) ||
        invalidVulnerabilityAge(rules) ||
        invalidVulnerabilityAttributes(rules)
      );
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :custom-save-button-text="$options.i18n.createMergeRequest"
    :disable-update="disableUpdate"
    :has-parsing-error="hasParsingError"
    :is-editing="isEditing"
    :is-removing-policy="isRemovingPolicy"
    :is-updating-policy="isCreatingMR"
    :parsing-error="$options.i18n.PARSING_ERROR_MESSAGE"
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
          <h4>{{ $options.RULES_LABEL }}</h4>
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
          @changed="updateRule(index, $event)"
          @remove="removeRule(index)"
        />

        <div
          v-if="isWithinLimit"
          class="security-policies-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5"
        >
          <gl-button variant="link" data-testid="add-rule" icon="plus" @click="addRule">
            {{ $options.ADD_RULE_LABEL }}
          </gl-button>
        </div>
      </dim-disable-container>
    </template>
    <template #actions>
      <dim-disable-container data-testid="actions-section" :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <div v-if="showBotMessageAction">
          <action-section
            v-for="(action, index) in actionsForRuleMode"
            :key="action.id"
            :data-testid="`action-${index}`"
            class="gl-mb-4"
            :action-index="index"
            :init-action="action"
            :errors="errors.action"
            :existing-approvers="existingApprovers"
            @error="handleParsingError"
            @updateApprovers="updatePolicyApprovers"
            @changed="updateAction"
            @remove="removeApproverAction"
          />

          <scan-filter-selector
            v-if="availableActionListboxItems.length"
            class="gl-w-full"
            :button-text="$options.i18n.buttonText"
            :header="$options.i18n.filterHeaderText"
            :filters="availableActionListboxItems"
            @select="addAction"
          />
        </div>
        <div v-else-if="Boolean(policy.actions)">
          <approver-action
            v-for="(action, index) in policy.actions"
            :key="action.id"
            :data-testid="`action-${index}`"
            class="gl-mb-4"
            :init-action="action"
            :errors="errors.action"
            :existing-approvers="existingApprovers"
            @error="handleParsingError"
            @updateApprovers="updatePolicyApprovers"
            @changed="oldUpdateAction(index, $event)"
            @remove="oldRemoveAction(index)"
          />
        </div>
        <div v-else class="gl-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5">
          <gl-button variant="link" data-testid="add-action" icon="plus" @click="oldAddAction">
            {{ $options.i18n.ADD_ACTION_LABEL }}
          </gl-button>
        </div>
      </dim-disable-container>
    </template>
    <template #settings>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.settingsTitle }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <settings-section :rules="policy.rules" :settings="settings" @changed="updateSettings" />
      </dim-disable-container>
      <fallback-section
        :property="fallbackBehaviorSetting"
        :disabled="hasParsingError"
        @changed="handleUpdateProperty"
      />
      <gl-alert
        v-if="!hasParsingError && !hasRequireApprovalAction"
        data-testid="empty-actions-alert"
        class="gl-mb-5"
        :title="settingAlert.title"
        :variant="settingAlert.variant"
        :dismissible="false"
      >
        {{ settingAlert.description }}
      </gl-alert>
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
