<script>
import { GlEmptyState } from '@gitlab/ui';
import { joinPaths, setUrlFragment, visitUrl } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import {
  ACTIONS_LABEL,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  GRAPHQL_ERROR_MESSAGE,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
} from '../constants';
import { assignSecurityPolicyProject, modifyPolicy } from '../utils';
import EditorLayout from '../editor_layout.vue';
import DimDisableContainer from '../dim_disable_container.vue';
import ActionSection from './action/action_section.vue';
import RuleSection from './rule/rule_section.vue';
import { createPolicyObject, fromYaml, policyToYaml } from './utils';
import { CONDITIONS_LABEL, DEFAULT_PIPELINE_EXECUTION_POLICY } from './constants';

export default {
  ACTION: 'actions',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  i18n: {
    ACTIONS_LABEL,
    CONDITIONS_LABEL,
    PARSING_ERROR_MESSAGE,
    notOwnerButtonText: __('Learn more'),
    createMergeRequest: s__('SecurityOrchestration|Update via merge request'),
  },
  components: {
    ActionSection,
    DimDisableContainer,
    GlEmptyState,
    EditorLayout,
    RuleSection,
  },
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespacePath',
    'scanPolicyDocumentationPath',
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
    let yamlEditorValue;

    if (this.existingPolicy) {
      yamlEditorValue = policyToYaml(this.existingPolicy);
    } else {
      yamlEditorValue = DEFAULT_PIPELINE_EXECUTION_POLICY;
    }

    const { policy, hasParsingError } = createPolicyObject(yamlEditorValue);
    const parsingError = hasParsingError ? this.$options.i18n.PARSING_ERROR_MESSAGE : '';

    return {
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'pipeline-execution-policy-editor',
      ),
      hasParsingError,
      isCreatingMR: false,
      isRemovingPolicy: false,
      mode: EDITOR_MODE_RULE,
      parsingError,
      policy,
      yamlEditorValue,
    };
  },
  computed: {
    originalName() {
      return this.existingPolicy?.name;
    },
    strategy() {
      return this.policy.pipeline_config_strategy;
    },
  },
  methods: {
    changeEditorMode(mode) {
      this.mode = mode;
    },
    async getSecurityPolicyProject() {
      if (!this.newlyCreatedPolicyProject && !this.assignedPolicyProject.fullPath) {
        this.newlyCreatedPolicyProject = await assignSecurityPolicyProject(this.namespacePath);
      }

      return this.newlyCreatedPolicyProject || this.assignedPolicyProject;
    },
    handleError(error) {
      if (error.message.toLowerCase().includes('graphql')) {
        this.$emit('error', GRAPHQL_ERROR_MESSAGE);
      } else {
        this.$emit('error', error.message);
      }
    },
    async handleModifyPolicy(act) {
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
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateYaml(manifest) {
      const { policy, hasParsingError } = createPolicyObject(manifest);

      this.yamlEditorValue = manifest;
      this.hasParsingError = hasParsingError;
      this.parsingError = hasParsingError ? this.$options.i18n.PARSING_ERROR_MESSAGE : '';
      this.policy = policy;
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
    setLoadingFlag(action, val) {
      if (action === SECURITY_POLICY_ACTIONS.REMOVE) {
        this.isRemovingPolicy = val;
      } else {
        this.isCreatingMR = val;
      }
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
    @update-editor-mode="changeEditorMode"
    @update-property="handleUpdateProperty"
    @update-yaml="handleUpdateYaml"
  >
    <template #rules>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <rule-section class="gl-mb-4" />
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

        <action-section
          class="gl-mb-4 security-policies-bg-gray-10 gl-rounded-base gl-p-5"
          :action="policy.content"
          :strategy="strategy"
          @changed="handleUpdateProperty"
        />
      </dim-disable-container>
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
