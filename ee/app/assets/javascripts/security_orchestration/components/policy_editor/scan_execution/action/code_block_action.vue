<script>
import { GlSprintf } from '@gitlab/ui';
import { debounce } from 'lodash';
import Api from 'ee/api';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import CodeBlockSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_source_selector.vue';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import { parseCustomFileConfiguration } from 'ee/security_orchestration/components/policy_editor/utils';
import {
  buildCustomCodeAction,
  fromYaml,
  toYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';
import SectionLayout from '../../section_layout.vue';
import { ACTION_AND_LABEL } from '../../constants';
import {
  CUSTOM_ACTION_OPTIONS,
  CUSTOM_ACTION_OPTIONS_LISTBOX_ITEMS,
  CUSTOM_ACTION_OPTIONS_KEYS,
  INSERTED_CODE_BLOCK,
  LINKED_EXISTING_FILE,
} from '../constants';
import CodeBlockFilePath from './code_block_file_path.vue';
import CodeBlockImport from './code_block_import.vue';

export default {
  SCAN_EXECUTION_PATH: helpPagePath('user/application_security/policies/scan-execution-policies', {
    anchor: 'scan-action-type',
  }),
  ACTION_AND_LABEL,
  CUSTOM_ACTION_OPTIONS_KEYS,
  CUSTOM_ACTION_OPTIONS_LISTBOX_ITEMS,
  i18n: {
    customSectionHeaderCopy: s__(
      'ScanExecutionPolicy|%{boldStart}Run%{boldEnd} %{typeSelector} %{actionType}',
    ),
    customSectionTypeLabel: s__('ScanExecutionPolicy|Choose a method to execute code'),
    popoverTitle: __('Information'),
    popoverContent: s__(
      'ScanExecutionPolicy|If there are any conflicting variables with the local pipeline configuration (Ex, gitlab-ci.yml) then variables defined here will take precedence. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'CodeBlockAction',
  components: {
    CodeBlockSourceSelector,
    CodeBlockFilePath,
    CodeBlockImport,
    GlSprintf,
    SectionLayout,
    PolicyPopover,
    YamlEditor: () =>
      import(
        /* webpackChunkName: 'policy_yaml_editor' */ 'ee/security_orchestration/components/yaml_editor.vue'
      ),
  },
  props: {
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
    initAction: {
      type: Object,
      required: true,
    },
  },
  data() {
    const { showLinkedFile } = parseCustomFileConfiguration(
      fromYaml({ manifest: this.initAction?.ci_configuration || '' })?.include,
    );

    const yamlEditorValue = (this.initAction?.ci_configuration || '').trim();

    return {
      doesFileExist: true,
      selectedProject: undefined,
      selectedType: showLinkedFile ? LINKED_EXISTING_FILE : INSERTED_CODE_BLOCK,
      yamlEditorValue,
    };
  },
  computed: {
    ciConfigurationPath() {
      return this.ciConfigurationParsed?.include || {};
    },
    ciConfigurationParsed() {
      return fromYaml({ manifest: this.initAction?.ci_configuration || '' });
    },
    filePath() {
      return this.ciConfigurationPath.file;
    },
    selectedRef() {
      return this.ciConfigurationPath.ref;
    },
    hasExistingCode() {
      return Boolean(this.yamlEditorValue.length);
    },
    isFirstAction() {
      return this.actionIndex === 0;
    },
    isLinkedFile() {
      return this.selectedType === LINKED_EXISTING_FILE;
    },
    toggleText() {
      return CUSTOM_ACTION_OPTIONS[this.selectedType] || this.$options.i18n.customSectionTypeLabel;
    },
  },
  watch: {
    filePath() {
      this.resetValidation();
      this.handleFileValidation();
    },
    selectedProject() {
      this.resetValidation();
      this.handleFileValidation();
    },
    selectedRef() {
      this.resetValidation();
      this.handleFileValidation();
    },
  },
  created() {
    this.handleFileValidation = debounce(this.validateFilePath, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  async mounted() {
    const { project: selectedProject } = parseCustomFileConfiguration(
      fromYaml({ manifest: this.initAction?.ci_configuration || '' })?.include,
    );

    if (selectedProject && selectedProject.fullPath) {
      selectedProject.id = await this.getProjectId(selectedProject.fullPath);
      this.selectedProject = selectedProject;
    }

    this.validateFilePath();
  },
  methods: {
    async getProjectId(fullPath) {
      try {
        const { data } = await this.$apollo.query({
          query: getProjectId,
          variables: {
            fullPath,
          },
        });

        return data.project?.id || '';
      } catch (e) {
        return '';
      }
    },
    resetActionToDefault() {
      this.$emit('changed', buildCustomCodeAction(this.initAction.id));
    },
    resetValidation() {
      if (!this.doesFileExist) {
        this.doesFileExist = true;
      }
    },
    setSelectedType(type) {
      this.selectedType = type;
      this.selectedProject = null;
      this.yamlEditorValue = '';
      this.resetActionToDefault();
    },
    updateYaml(val) {
      this.yamlEditorValue = val;

      this.triggerChanged({
        ci_configuration: val,
      });
    },
    setSelectedRef(ref) {
      this.setCiConfigurationPath({
        ...this.ciConfigurationPath,
        ref,
      });
    },
    setSelectedProject(project) {
      this.selectedProject = null;
      this.$nextTick(() => {
        this.selectedProject = project;

        const config = { ...this.ciConfigurationPath };

        if ('ref' in config) delete config.ref;

        if (project) {
          config.project = project?.fullPath;
        } else {
          delete config.project;
        }

        this.setCiConfigurationPath({ ...config });
      });
    },
    updatedFilePath(path) {
      this.setCiConfigurationPath({
        ...this.ciConfigurationPath,
        file: path,
      });
    },
    async validateFilePath() {
      const selectedProjectId = getIdFromGraphQLId(this.selectedProject?.id);
      const ref = this.selectedRef || this.selectedProject?.repository?.rootRef;

      // For when the id is removed or when selectedProject is set to null temporarily above
      if (!selectedProjectId) {
        this.doesFileExist = false;
        return;
      }

      // For existing policies with existing project selected, rootRef will not be available
      if (!ref) {
        this.doesFileExist = true;
        return;
      }

      try {
        await Api.getFile(selectedProjectId, this.filePath, { ref });
        this.doesFileExist = true;
      } catch {
        this.doesFileExist = false;
      }
    },
    setCiConfigurationPath(pathConfig) {
      this.triggerChanged({
        ci_configuration: toYaml({
          include: {
            ...pathConfig,
          },
        }),
      });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initAction, ...value });
    },
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-text-gray-500 gl-mb-4 gl-ml-5"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>

    <section-layout @remove="$emit('remove')">
      <template #content>
        <div class="gl-display-inline-flex gl-w-full gl-gap-3 gl-align-items-center gl-flex-wrap">
          <div
            class="gl-display-inline-flex gl-w-full gl-gap-3 gl-align-items-baseline gl-flex-wrap gl-md-flex-nowrap"
          >
            <gl-sprintf :message="$options.i18n.customSectionHeaderCopy">
              <template #bold="{ content }">
                <b v-if="!isLinkedFile">{{ content }}</b>
              </template>

              <template #typeSelector>
                <div v-if="!isLinkedFile" class="gl-display-flex gl-align-items-center gl-gap-3">
                  <code-block-source-selector
                    :selected-type="selectedType"
                    @select="setSelectedType"
                  />

                  <policy-popover
                    :content="$options.i18n.popoverContent"
                    :title="$options.i18n.popoverTitle"
                    :href="$options.SCAN_EXECUTION_PATH"
                    target="code-block-action-icon"
                  />
                </div>
              </template>

              <template #actionType>
                <code-block-file-path
                  v-if="isLinkedFile"
                  :file-path="filePath"
                  :selected-type="selectedType"
                  :selected-ref="selectedRef"
                  :selected-project="selectedProject"
                  :does-file-exist="doesFileExist"
                  @select-ref="setSelectedRef"
                  @select-type="setSelectedType"
                  @select-project="setSelectedProject"
                  @update-file-path="updatedFilePath"
                />
              </template>
            </gl-sprintf>
          </div>
        </div>

        <div
          v-if="!isLinkedFile"
          class="editor gl-w-full gl-overflow-y-auto gl-rounded-base gl-h-200!"
        >
          <yaml-editor
            data-testid="custom-yaml-editor"
            policy-type="scan_execution_policy"
            :file-global-id="initAction.id"
            :disable-schema="true"
            :value="yamlEditorValue"
            :read-only="false"
            @input="updateYaml"
          />
        </div>

        <code-block-import
          v-if="!isLinkedFile"
          :has-existing-code="hasExistingCode"
          @changed="updateYaml"
        />
      </template>
    </section-layout>
  </div>
</template>
