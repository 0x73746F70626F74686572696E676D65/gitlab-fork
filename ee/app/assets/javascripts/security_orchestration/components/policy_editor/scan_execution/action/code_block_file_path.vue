<script>
import {
  GlFormGroup,
  GlFormInputGroup,
  GlIcon,
  GlInputGroupText,
  GlSprintf,
  GlFormInput,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { BV_SHOW_TOOLTIP, BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import RefSelector from '~/ref/components/ref_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { validateStrategyValues } from '../lib';
import { INJECT, OVERRIDE } from '../constants';
import CodeBlockSourceSelector from './code_block_source_selector.vue';
import CodeBlockStrategySelector from './code_block_strategy_selector.vue';

export default {
  i18n: {
    filePathInputCopy: s__('ScanExecutionPolicy|%{labelStart}File path:%{labelEnd} %{filePath}'),
    filePathCopy: s__(
      'ScanExecutionPolicy|%{boldStart}Run%{boldEnd} %{typeSelector} from the project %{projectSelector} with ref %{refSelector}',
    ),
    pipelineFilePathCopy: {
      [INJECT]: s__(
        'ScanExecutionPolicy|%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      ),
      [OVERRIDE]: s__(
        'ScanExecutionPolicy|%{strategySelector}the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      ),
    },
    filePathPrependLabel: __('No project selected'),
    fileRefLabel: s__('ScanExecutionPolicy|Select ref'),
    fileRefCopy: s__('ScanExecutionPolicy|File reference (Optional) %{refSelector}'),
    filePathInputPlaceholder: s__('ScanExecutionPolicy|Link existing CI file'),
    filePathInputEmptyMessage: s__("ScanExecutionPolicy|The file path can't be empty"),
    filePathInputDoesNotExistMessage: s__(
      "ScanExecutionPolicy|The file at that project, ref, and path doesn't exist",
    ),
    formGroupLabel: s__('ScanExecutionPolicy|file path group'),
    selectedProjectInformation: {
      [INJECT]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      ),
      [OVERRIDE]: s__(
        'ScanExecutionPolicy|The content of this pipeline execution YAML file overrides the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      ),
    },
    tooltipText: s__('ScanExecutionPolicy|Select project first, and then insert a file path'),
  },
  refSelectorTranslations: {
    noRefSelected: __('default branch'),
  },
  SELECTED_PROJECT_TOOLTIP: 'selected-project-tooltip',
  name: 'CodeBlockFilePath',
  components: {
    CodeBlockStrategySelector,
    CodeBlockSourceSelector,
    GlIcon,
    GlFormGroup,
    GlFormInputGroup,
    GlFormInput,
    GlInputGroupText,
    GlSprintf,
    GlTruncate,
    GroupProjectsDropdown,
    RefSelector,
  },
  directives: { GlTooltip: GlTooltipDirective },
  mixins: [glFeatureFlagMixin()],
  inject: ['namespacePath', 'rootNamespacePath', 'namespaceType'],
  props: {
    strategy: {
      type: String,
      required: false,
      default: INJECT,
      validator: validateStrategyValues,
    },
    selectedType: {
      type: String,
      required: false,
      default: '',
    },
    filePath: {
      type: String,
      required: false,
      default: null,
    },
    doesFileExist: {
      type: Boolean,
      required: false,
      default: true,
    },
    selectedRef: {
      type: String,
      required: false,
      default: '',
    },
    selectedProject: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isPipelineExecution() {
      return this.glFeatures.pipelineExecutionPolicyType;
    },
    fileBlockMessage() {
      return this.isPipelineExecution
        ? this.$options.i18n.pipelineFilePathCopy[this.strategy]
        : this.$options.i18n.filePathCopy;
    },
    isValidFilePath() {
      if (this.filePath === null) {
        return null;
      }

      return Boolean(this.filePath);
    },
    projectAndRefState() {
      return !this.isValidFilePath || this.doesFileExist;
    },
    filePathState() {
      return this.isValidFilePath && this.doesFileExist;
    },
    filePathValidationError() {
      if (!this.isValidFilePath) {
        return this.$options.i18n.filePathInputEmptyMessage;
      }

      if (!this.doesFileExist) {
        return this.$options.i18n.filePathInputDoesNotExistMessage;
      }

      return '';
    },
    selectedProjectId() {
      return this.selectedProject?.id;
    },
    selectedProjectIdShortFormat() {
      const value = getIdFromGraphQLId(this.selectedProjectId);
      return value ? value.toString() : '';
    },
    selectedProjectFullPath() {
      return this.selectedProject?.fullPath || this.$options.i18n.filePathPrependLabel;
    },
    selectedProjectTooltip() {
      return this.selectedProject?.fullPath || this.$options.i18n.tooltipText;
    },
    groupProjectsPath() {
      return isGroup(this.namespaceType) ? this.namespacePath : this.rootNamespacePath;
    },
    selectedProjectInformationText() {
      return this.$options.i18n.selectedProjectInformation[this.strategy];
    },
  },
  methods: {
    updatedFilePath(value) {
      this.$emit('update-file-path', value);
    },
    setStrategy(strategy) {
      this.$emit('select-strategy', strategy);
    },

    setSelectedProject(project) {
      this.$emit('select-project', project);
    },
    setSelectedType(type) {
      this.$emit('select-type', type);
    },
    setSelectedRef(ref) {
      this.$emit('select-ref', ref);
    },
    triggerTooltip(state) {
      const EVENT = state ? BV_SHOW_TOOLTIP : BV_HIDE_TOOLTIP;
      this.$root.$emit(EVENT, this.$options.SELECTED_PROJECT_TOOLTIP);
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-w-full gl-flex-direction-column gl-gap-3">
    <div class="gl-display-flex gl-gap-3 gl-align-items-center gl-flex-wrap">
      <gl-sprintf :message="fileBlockMessage">
        <template #strategySelector>
          <code-block-strategy-selector :strategy="strategy" @select="setStrategy" />
        </template>

        <template #bold="{ content }">
          <b>{{ content }}</b>
        </template>

        <template #typeSelector>
          <code-block-source-selector :selected-type="selectedType" @select="setSelectedType" />
        </template>

        <template #projectSelector>
          <group-projects-dropdown
            class="gl-max-w-20"
            :group-full-path="groupProjectsPath"
            :selected="selectedProjectId"
            :multiple="false"
            :state="projectAndRefState"
            @select="setSelectedProject"
          />
          <gl-icon
            v-if="isPipelineExecution"
            v-gl-tooltip
            name="information-o"
            :title="selectedProjectInformationText"
          />
        </template>

        <template #refSelector>
          <ref-selector
            v-if="selectedProjectId"
            class="gl-max-w-20"
            :project-id="selectedProjectIdShortFormat"
            :state="projectAndRefState"
            :translations="$options.refSelectorTranslations"
            :value="selectedRef"
            @input="setSelectedRef"
          />

          <gl-form-input
            v-else
            class="gl-w-auto"
            :placeholder="$options.i18n.fileRefLabel"
            :state="projectAndRefState"
            :value="selectedRef"
            @input="setSelectedRef"
          />
        </template>
      </gl-sprintf>
    </div>

    <div class="gl-display-flex gl-w-full gl-gap-3 gl-align-items-baseline gl-flex-nowrap">
      <gl-sprintf :message="$options.i18n.filePathInputCopy">
        <template #label="{ content }">
          <span class="gl-whitespace-nowrap">{{ content }}</span>
        </template>

        <template #filePath>
          <gl-form-group
            class="gl-w-full gl-mb-0"
            label-sr-only
            :label="$options.i18n.formGroupLabel"
            :optional="false"
            :invalid-feedback="filePathValidationError"
            :state="filePathState"
          >
            <gl-form-input-group
              id="file-path"
              :placeholder="$options.i18n.filePathInputPlaceholder"
              :state="filePathState"
              :disabled="!selectedProjectId"
              :value="filePath"
              @mouseenter="triggerTooltip(true)"
              @mouseleave="triggerTooltip(false)"
              @input="updatedFilePath"
            >
              <template #prepend>
                <gl-input-group-text
                  v-gl-tooltip="{
                    id: $options.SELECTED_PROJECT_TOOLTIP,
                    title: selectedProjectTooltip,
                  }"
                  :class="{ 'gl-border-gray-100': !selectedProjectId }"
                  class="gl-max-w-26 gl-max-h-full!"
                >
                  <gl-truncate :text="selectedProjectFullPath" position="start" />
                </gl-input-group-text>
              </template>
            </gl-form-input-group>
          </gl-form-group>
        </template>
      </gl-sprintf>
    </div>

    <div
      v-if="isPipelineExecution"
      data-testid="pipeline-execution-ref-selector"
      class="gl-flex gl-w-full gl-gap-3 gl-items-baseline gl-flex-nowrap"
    >
      <gl-sprintf :message="$options.i18n.fileRefCopy">
        <template #refSelector>
          <ref-selector
            v-if="selectedProjectId"
            class="gl-max-w-20"
            :project-id="selectedProjectIdShortFormat"
            :state="projectAndRefState"
            :translations="$options.refSelectorTranslations"
            :value="selectedRef"
            @input="setSelectedRef"
          />

          <gl-form-input
            v-else
            class="gl-w-auto"
            :placeholder="$options.i18n.fileRefLabel"
            :state="projectAndRefState"
            :value="selectedRef"
            @input="setSelectedRef"
          />
        </template>
      </gl-sprintf>
    </div>
  </div>
</template>
