<script>
import { debounce } from 'lodash';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import Api from 'ee/api';
import { parseCustomFileConfiguration } from 'ee/security_orchestration/components/policy_editor/utils';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';
import CodeBlockFilePath from '../../scan_execution/action/code_block_file_path.vue';

export default {
  components: {
    CodeBlockFilePath,
  },
  props: {
    action: {
      type: Object,
      required: true,
    },
    strategy: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      doesFileExist: true,
      selectedProject: undefined,
    };
  },
  computed: {
    ciConfigurationPath() {
      return this.action.include || {};
    },
    filePath() {
      return this.ciConfigurationPath.file;
    },
    selectedRef() {
      return this.ciConfigurationPath.ref;
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
    const { project: selectedProject } = parseCustomFileConfiguration(this.action.include);

    if (selectedProject && selectedProject.fullPath) {
      selectedProject.id = await this.getProjectId(selectedProject.fullPath);
      this.selectedProject = selectedProject;
    }

    if (!this.selectedProject) {
      this.validateFilePath();
    }
  },
  destroyed() {
    this.handleFileValidation.cancel();
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
    resetValidation() {
      if (!this.doesFileExist) {
        this.doesFileExist = true;
      }
    },
    setStrategy(strategy) {
      this.$emit('changed', 'pipeline_config_strategy', strategy);
    },
    setSelectedRef(ref) {
      this.setCiConfigurationPath({ ...this.ciConfigurationPath, ref });
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
      this.setCiConfigurationPath({ ...this.ciConfigurationPath, file: path });
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
      this.$emit('changed', 'content', { include: pathConfig });
    },
  },
};
</script>

<template>
  <code-block-file-path
    is-pipeline-execution
    :file-path="filePath"
    :strategy="strategy"
    :selected-ref="selectedRef"
    :selected-project="selectedProject"
    :does-file-exist="doesFileExist"
    @select-strategy="setStrategy"
    @select-ref="setSelectedRef"
    @select-project="setSelectedProject"
    @update-file-path="updatedFilePath"
  />
</template>
