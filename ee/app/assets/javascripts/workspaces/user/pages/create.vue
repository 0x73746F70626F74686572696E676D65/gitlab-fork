<!-- eslint-disable vue/multi-word-component-names -->
<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlFormInputGroup,
  GlIcon,
  GlPopover,
  GlTooltipDirective,
  GlLink,
} from '@gitlab/ui';
import { omit } from 'lodash';
import { s__, __ } from '~/locale';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { logError } from '~/lib/logger';
import { helpPagePath } from '~/helpers/help_page_helper';
import RefSelector from '~/ref/components/ref_selector.vue';
import GetProjectDetailsQuery from '../../common/components/get_project_details_query.vue';
import WorkspaceVariables from '../components/workspace_variables.vue';
import SearchProjectsListbox from '../components/search_projects_listbox.vue';
import workspaceCreateMutation from '../graphql/mutations/workspace_create.mutation.graphql';
import { addWorkspace } from '../services/apollo_cache_mutators';
import {
  DEFAULT_DESIRED_STATE,
  DEFAULT_DEVFILE_PATH,
  DEFAULT_EDITOR,
  ROUTES,
  PROJECT_VISIBILITY,
} from '../constants';

export const i18n = {
  devfileRefHelp: s__(
    'Workspaces|The branch, tag, or commit hash GitLab uses to create your workspace.',
  ),
  title: s__('Workspaces|New workspace'),
  subtitle: s__('Workspaces|A workspace is a virtual sandbox environment for your code in GitLab.'),
  form: {
    devfileProject: s__('Workspaces|Project'),
    gitReference: s__('Workspaces|Git reference'),
    devfileLocation: {
      label: s__('Workspaces|Devfile location'),
      title: s__('Workspaces|What is a devfile?'),
      contentParagraph1: s__(
        'Workspaces|A devfile defines the development environment for a GitLab project. A workspace must have a valid devfile in the Git reference you use.',
      ),
      contentParagraph2: s__(
        'Workspaces|If your devfile is not in the root directory of your project, specify a relative path.',
      ),
      linkText: s__('Workspaces|Learn more.'),
    },
    pathToDevfile: s__('Workspaces|Path to devfile'),
    agentId: s__('Workspaces|Cluster agent'),
    maxHoursBeforeTermination: s__('Workspaces|Workspace automatically terminates after'),
    maxHoursSuffix: __('hours'),
  },
  invalidProjectAlert: {
    title: s__("Workspaces|You can't create a workspace for this project"),
    noAgentsContent: s__(
      'Workspaces|You must have access to a cluster agent. An administrator can configure an agent for the project or group.',
    ),
    noDevFileContent: s__(
      'Workspaces|To create a workspace, add a devfile to this project. A devfile is a configuration file for your workspace.',
    ),
  },
  submitButton: {
    create: s__('Workspaces|Create workspace'),
  },
  cancelButton: s__('Workspaces|Cancel'),
  createWorkspaceFailedMessage: s__('Workspaces|Failed to create workspace'),
  fetchProjectDetailsFailedMessage: s__(
    'Workspaces|Could not retrieve cluster agents for this project',
  ),
};

export const devfileHelpPath = helpPagePath('user/workspace/index.md#devfile');

export default {
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInputGroup,
    GlFormSelect,
    GlFormInput,
    GlIcon,
    GlPopover,
    GlLink,
    RefSelector,
    SearchProjectsListbox,
    GetProjectDetailsQuery,
    WorkspaceVariables,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['defaultMaxHoursBeforeTermination'],
  data() {
    return {
      selectedProject: null,
      selectedAgent: null,
      isCreatingWorkspace: false,
      clusterAgents: [],
      devfileRef: '',
      devfilePath: DEFAULT_DEVFILE_PATH,
      projectId: null,
      maxHoursBeforeTermination: this.defaultMaxHoursBeforeTermination,
      workspaceVariables: [],
      showWorkspaceVariableValidations: false,
      projectDetailsLoaded: false,
      error: '',
    };
  },
  computed: {
    emptyAgents() {
      return this.clusterAgents.length === 0;
    },
    displayClusterAgentsAlert() {
      return this.projectDetailsLoaded && this.emptyAgents;
    },
    saveWorkspaceEnabled() {
      return this.selectedProject && this.selectedAgent;
    },
    selectedProjectFullPath() {
      return this.selectedProject?.fullPath || this.$router.currentRoute.query?.project;
    },
    selectedProjectFullPathDisplay() {
      return `${this.selectedProjectFullPath.split('/').join(' / ')} /`;
    },
    projectApiId() {
      if (!this.projectId) {
        return '';
      }
      return String(getIdFromGraphQLId(this.projectId));
    },
  },
  watch: {
    emptyAgents(newValue) {
      if (!newValue) {
        this.focusAgentSelectDropdown();
      }
    },
  },
  mounted() {
    this.focusFirstElement();
  },
  methods: {
    onProjectDetailsResult({ fullPath, nameWithNamespace, clusterAgents, id, rootRef }) {
      // This scenario happens when the selected project is specified in the URL as a query param
      if (!this.selectedProject) {
        this.setSelectedProject({ fullPath, nameWithNamespace });
      }

      this.projectDetailsLoaded = true;
      this.projectId = id;
      this.devfileRef = rootRef;

      this.clusterAgents = clusterAgents;

      // Select the first agent if there are any
      if (clusterAgents.length > 0) {
        this.selectedAgent = clusterAgents[0].value;
      }
    },
    onProjectDetailsError() {
      createAlert({ message: i18n.fetchProjectDetailsFailedMessage });
      this.resetProjectDetails();
    },
    onSelectProjectFromListbox(selectedProject) {
      this.setSelectedProject(selectedProject);
      this.resetProjectDetails();
    },
    setSelectedProject(selectedProject) {
      this.selectedProject = selectedProject;
    },
    resetProjectDetails() {
      this.clusterAgents = [];
      this.selectedAgent = null;
      this.projectDetailsLoaded = false;
    },
    validateWorkspaceVariables() {
      this.showWorkspaceVariableValidations = true;
      return this.workspaceVariables.every((variable) => {
        return variable.valid === true;
      });
    },
    async createWorkspace() {
      if (!this.validateWorkspaceVariables()) {
        return;
      }
      try {
        this.isCreatingWorkspace = true;

        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const result = await this.$apollo.mutate({
          mutation: workspaceCreateMutation,
          variables: {
            input: {
              projectId: this.projectId,
              clusterAgentId: this.selectedAgent,
              editor: DEFAULT_EDITOR,
              desiredState: DEFAULT_DESIRED_STATE,
              devfileRef: this.devfileRef,
              devfilePath: this.devfilePath,
              maxHoursBeforeTermination: parseInt(this.maxHoursBeforeTermination, 10),
              variables: this.workspaceVariables.map((v) => omit(v, 'valid')),
            },
          },
          update(store, { data }) {
            if (data.workspaceCreate.errors.length > 0) {
              return;
            }

            addWorkspace(store, data.workspaceCreate.workspace);
          },
        });

        const {
          errors: [error],
        } = result.data.workspaceCreate;

        if (error) {
          this.error = error;
          return;
        }

        // noinspection ES6MissingAwait - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        this.$router.push(ROUTES.index);
      } catch (error) {
        logError(error);
        this.error = i18n.createWorkspaceFailedMessage;
      } finally {
        this.isCreatingWorkspace = false;
      }
    },
    focusFirstElement() {
      const formElement = this.$refs.form.$el;

      formElement.elements?.[0]?.focus();
    },
    focusAgentSelectDropdown() {
      this.$nextTick(() => {
        // noinspection JSUnresolvedReference - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        this.$refs.agentSelect.$el.focus();
      });
    },
  },
  i18n,
  ROUTES,
  PROJECT_VISIBILITY,
  devfileHelpPath,
};
</script>
<template>
  <div class="gl-flex gl-flex-row gl-gap-5">
    <div class="gl-flex-basis-third">
      <div class="gl-flex gl-items-center">
        <h2 ref="pageTitle" class="page-title gl-font-size-h-display">
          {{ $options.i18n.title }}
        </h2>
      </div>
      <p>
        {{ $options.i18n.subtitle }}
      </p>
    </div>
    <get-project-details-query
      :project-full-path="selectedProjectFullPath"
      @result="onProjectDetailsResult"
      @error="onProjectDetailsError"
    />
    <gl-form ref="form" class="gl-mt-6 gl-flex-basis-two-thirds" @submit.prevent="createWorkspace">
      <gl-form-group
        :label="$options.i18n.form.devfileProject"
        label-for="workspace-devfile-project-id"
      >
        <search-projects-listbox
          id="workspace-search-projects-listbox"
          :value="selectedProject"
          data-testid="workspace-devfile-project-id-field"
          @input="onSelectProjectFromListbox"
        />
        <gl-alert
          v-if="displayClusterAgentsAlert"
          data-testid="no-agents-alert"
          class="gl-mt-3"
          :title="$options.i18n.invalidProjectAlert.title"
          variant="danger"
          :dismissible="false"
        >
          {{ $options.i18n.invalidProjectAlert.noAgentsContent }}
        </gl-alert>
      </gl-form-group>
      <template v-if="!emptyAgents">
        <gl-form-group
          class="gl-mb-3"
          :label="$options.i18n.form.agentId"
          label-for="workspace-cluster-agent-id"
          data-testid="workspace-cluster-agent-form-group"
        >
          <gl-form-select
            id="workspace-cluster-agent-id"
            ref="agentSelect"
            v-model="selectedAgent"
            :options="clusterAgents"
            required
            class="gl-max-w-full"
            autocomplete="off"
            data-testid="workspace-cluster-agent-id-field"
          />
        </gl-form-group>
        <template v-if="selectedAgent">
          <gl-form-group class="gl-mb-2" data-testid="devfile-ref">
            <label class="gl-flex gl-items-center gl-gap-3" for="workspace-devfile-ref">
              {{ $options.i18n.form.gitReference }}
              <gl-icon
                v-gl-tooltip="$options.i18n.devfileRefHelp"
                name="information-o"
                :size="14"
              />
            </label>
            <div class="gl-flex">
              <ref-selector
                id="workspace-devfile-ref"
                v-model="devfileRef"
                :project-id="projectApiId"
              />
            </div>
          </gl-form-group>
          <gl-form-group data-testid="devfile-path">
            <div class="gl-flex gl-flex-row gl-items-center gl-gap-3 gl-mb-3">
              <label class="gl-flex gl-mb-0" for="workspace-devfile-path">
                {{ $options.i18n.form.devfileLocation.label }}
              </label>
              <gl-icon
                id="devfile-location-popover"
                class="gl-text-blue-600"
                name="question-o"
                :size="14"
              />
              <gl-popover
                triggers="hover focus"
                :title="$options.i18n.form.devfileLocation.title"
                placement="top"
                target="devfile-location-popover"
              >
                <div class="gl-flex gl-flex-col">
                  <p>{{ $options.i18n.form.devfileLocation.contentParagraph1 }}</p>
                  <p>{{ $options.i18n.form.devfileLocation.contentParagraph2 }}</p>
                </div>
                <gl-link :href="$options.devfileHelpPath" target="_blank">
                  {{ $options.i18n.form.devfileLocation.linkText }}
                </gl-link>
              </gl-popover>
            </div>
            <gl-form-input-group>
              <template #prepend>
                <div class="input-group-text">{{ selectedProjectFullPathDisplay }}</div>
              </template>
              <gl-form-input
                id="workspace-devfile-path"
                v-model="devfilePath"
                :placeholder="$options.i18n.form.pathToDevfile"
              />
            </gl-form-input-group>
          </gl-form-group>
          <gl-form-group
            data-testid="max-hours-before-termination"
            :label="$options.i18n.form.maxHoursBeforeTermination"
            label-for="workspace-max-hours-before-termination"
          >
            <gl-form-input-group>
              <gl-form-input
                id="workspace-max-hours-before-termination"
                v-model="maxHoursBeforeTermination"
                type="number"
                required
                autocomplete="off"
                width="xs"
              />
              <template #append>
                <div class="input-group-text">
                  {{ $options.i18n.form.maxHoursSuffix }}
                </div>
              </template>
            </gl-form-input-group>
          </gl-form-group>
          <workspace-variables
            v-model="workspaceVariables"
            class="mb-3"
            :show-validations="showWorkspaceVariableValidations"
            @addVariable="showWorkspaceVariableValidations = false"
          />
        </template>
      </template>
      <div class="gl-flex gl-gap-3">
        <gl-button
          class="gl-flex js-no-auto-disable"
          :loading="isCreatingWorkspace"
          :disabled="!saveWorkspaceEnabled"
          type="submit"
          data-testid="create-workspace"
          variant="confirm"
        >
          {{ $options.i18n.submitButton.create }}
        </gl-button>
        <gl-button class="gl-flex" data-testid="cancel-workspace" :to="$options.ROUTES.index">
          {{ $options.i18n.cancelButton }}
        </gl-button>
      </div>
      <gl-alert
        v-if="error"
        data-testid="create-workspace-error-alert"
        class="gl-mt-3"
        variant="danger"
        dismissible
        @dismiss="error = ''"
      >
        {{ error }}
      </gl-alert>
    </gl-form>
  </div>
</template>
