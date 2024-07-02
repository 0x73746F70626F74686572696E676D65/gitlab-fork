<script>
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
    doesFileExist: {
      type: Boolean,
      required: false,
      default: true,
    },
    strategy: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      selectedProject: undefined,
    };
  },
  computed: {
    ciConfigurationPath() {
      return this.action?.include?.[0] || {};
    },
    filePath() {
      return this.ciConfigurationPath.file;
    },
    selectedRef() {
      return this.ciConfigurationPath.ref;
    },
  },
  async mounted() {
    const { project: selectedProject } = parseCustomFileConfiguration(this.action.include?.[0]);

    if (selectedProject && selectedProject.fullPath) {
      selectedProject.id = await this.getProjectId(selectedProject.fullPath);
      this.selectedProject = selectedProject;
    }
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

        return data?.project?.id || '';
      } catch (e) {
        return '';
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
    setCiConfigurationPath(pathConfig) {
      this.$emit('changed', 'content', { include: [pathConfig] });
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
