import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { cloneDeep } from 'lodash';
import {
  GlForm,
  GlFormSelect,
  GlIcon,
  GlLink,
  GlSprintf,
  GlFormInput,
  GlFormInputGroup,
  GlPopover,
} from '@gitlab/ui';
import RefSelector from '~/ref/components/ref_selector.vue';
import SearchProjectsListbox from 'ee/workspaces/user/components/search_projects_listbox.vue';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import WorkspaceVariables from 'ee/workspaces/user/components/workspace_variables.vue';
import WorkspaceCreate, { devfileHelpPath, i18n } from 'ee/workspaces/user/pages/create.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import {
  DEFAULT_DESIRED_STATE,
  DEFAULT_EDITOR,
  ROUTES,
  WORKSPACE_VARIABLE_INPUT_TYPE_ENUM,
  WORKSPACES_LIST_PAGE_SIZE,
} from 'ee/workspaces/user/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import userWorkspacesListQuery from 'ee/workspaces/common/graphql/queries/user_workspaces_list.query.graphql';
import workspaceCreateMutation from 'ee/workspaces/user/graphql/mutations/workspace_create.mutation.graphql';
import {
  GET_PROJECT_DETAILS_QUERY_RESULT,
  USER_WORKSPACES_LIST_QUERY_RESULT,
  WORKSPACE_CREATE_MUTATION_RESULT,
  WORKSPACE_QUERY_RESULT,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');
jest.mock('~/alert');

describe('workspaces/user/pages/create.vue', () => {
  const DEFAULT_MAX_HOURS_BEFORE_TERMINATION = 42;
  const selectedProjectFixture = {
    fullPath: 'gitlab-org/gitlab',
    nameWithNamespace: 'GitLab Org / GitLab',
  };
  const selectedClusterAgentIDFixture = 'agents/1';
  const clusterAgentsFixture = [{ text: 'Agent', value: 'agents/1' }];
  const rootRefFixture = 'main';
  const GlFormSelectStub = stubComponent(GlFormSelect, {
    props: ['options'],
  });
  const mockRouter = {
    push: jest.fn(),
    currentRoute: {},
  };
  let wrapper;
  let workspaceCreateMutationHandler;
  let mockApollo;

  const buildMockApollo = () => {
    workspaceCreateMutationHandler = jest.fn();
    workspaceCreateMutationHandler.mockResolvedValueOnce(WORKSPACE_CREATE_MUTATION_RESULT);
    mockApollo = createMockApollo([[workspaceCreateMutation, workspaceCreateMutationHandler]]);
  };

  const readCachedWorkspaces = () => {
    const apolloClient = mockApollo.clients.defaultClient;
    const result = apolloClient.readQuery({
      query: userWorkspacesListQuery,
      variables: {
        before: null,
        after: null,
        first: WORKSPACES_LIST_PAGE_SIZE,
      },
    });

    return result?.currentUser.workspaces.nodes;
  };

  const writeCachedWorkspaces = (workspaces) => {
    const apolloClient = mockApollo.clients.defaultClient;
    apolloClient.writeQuery({
      query: userWorkspacesListQuery,
      variables: {
        before: null,
        after: null,
        first: WORKSPACES_LIST_PAGE_SIZE,
      },
      data: {
        currentUser: {
          ...USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser,
          workspaces: {
            nodes: workspaces,
            pageInfo: USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.pageInfo,
          },
        },
      },
    });
  };

  const createWrapper = () => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMountExtended(WorkspaceCreate, {
      apolloProvider: mockApollo,
      provide: {
        defaultMaxHoursBeforeTermination: DEFAULT_MAX_HOURS_BEFORE_TERMINATION,
      },
      stubs: {
        GlFormSelect: GlFormSelectStub,
        GlFormInputGroup,
        GlSprintf,
      },
      mocks: {
        $router: mockRouter,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const projectGid = GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id;
  const projectId = String(getIdFromGraphQLId(projectGid));
  const findSearchProjectsListbox = () => wrapper.findComponent(SearchProjectsListbox);
  const findNoAgentsGlAlert = () => wrapper.findByTestId('no-agents-alert');
  const findCreateWorkspaceErrorGlAlert = () =>
    wrapper.findByTestId('create-workspace-error-alert');
  const findClusterAgentsFormGroup = () =>
    wrapper.findByTestId('workspace-cluster-agent-form-group');
  const findGetProjectDetailsQuery = () => wrapper.findComponent(GetProjectDetailsQuery);
  const findCreateWorkspaceButton = () => wrapper.findByTestId('create-workspace');
  const findClusterAgentsFormSelect = () => wrapper.findComponent(GlFormSelectStub);

  const findDevfileRefField = () => wrapper.findByTestId('devfile-ref');
  const findDevfileRefRefSelector = () => findDevfileRefField().findComponent(RefSelector);
  const findDevfileRefFieldParts = () => {
    const field = findDevfileRefField();
    const icon = field.findComponent(GlIcon);

    return {
      label: field.find('label').text(),
      icon: icon.attributes('name'),
      iconTooltip: getBinding(icon.element, 'gl-tooltip').value,
    };
  };

  const findDevfilePathField = () => wrapper.findByTestId('devfile-path');
  const findDevfilePathInputGroup = () => findDevfilePathField().findComponent(GlFormInputGroup);
  const findDevfilePathInput = () => findDevfilePathInputGroup().findComponent(GlFormInput);
  const findDevfilePathFieldParts = () => {
    const field = findDevfilePathField();
    const popover = field.findComponent(GlPopover);

    return {
      label: field.find('label').text(),
      inputPrepend: findDevfilePathInputGroup().text(),
      inputPlaceholder: findDevfilePathInput().attributes('placeholder'),
      popoverText: popover.text(),
      popoverLinkHref: popover.findComponent(GlLink).attributes('href'),
      popoverLinkText: popover.findComponent(GlLink).text(),
    };
  };

  const findMaxHoursBeforeTerminationField = () =>
    wrapper.findByTestId('max-hours-before-termination');
  const findMaxHoursBeforeTerminationInputGroup = () =>
    findMaxHoursBeforeTerminationField().findComponent(GlFormInputGroup);
  const findMaxHoursBeforeTerminationInput = () =>
    findMaxHoursBeforeTerminationInputGroup().findComponent(GlFormInput);
  const findMaxHoursBeforeTerminationFieldParts = () => {
    const field = findMaxHoursBeforeTerminationField();
    const inputAppendText = findMaxHoursBeforeTerminationInputGroup().text();

    return {
      label: field.attributes('label'),
      inputAppendText,
    };
  };

  const emitGetProjectDetailsQueryResult = ({
    clusterAgents = [],
    groupPath = GET_PROJECT_DETAILS_QUERY_RESULT.data.project.group.fullPath,
    id = projectGid,
    rootRef = rootRefFixture,
    nameWithNamespace,
    fullPath,
  }) =>
    findGetProjectDetailsQuery().vm.$emit('result', {
      clusterAgents,
      groupPath,
      rootRef,
      id,
      nameWithNamespace,
      fullPath,
    });
  const selectProject = (project = selectedProjectFixture) =>
    findSearchProjectsListbox().vm.$emit('input', project);
  const selectClusterAgent = () =>
    findClusterAgentsFormSelect().vm.$emit('input', selectedClusterAgentIDFixture);
  const submitCreateWorkspaceForm = () =>
    wrapper.findComponent(GlForm).vm.$emit('submit', { preventDefault: jest.fn() });
  const findWorkspaceVariables = () => wrapper.findComponent(WorkspaceVariables);

  beforeEach(() => {
    buildMockApollo();
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays a cancel button that allows navigating to the workspaces list', () => {
      expect(wrapper.findByTestId('cancel-workspace').attributes().to).toBe(ROUTES.index);
    });

    it('disables create workspace button', () => {
      expect(findCreateWorkspaceButton().props().disabled).toBe(true);
    });
  });

  describe('when a project does not have cluster agents', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({ clusterAgents: [] });
    });

    it('displays danger alert indicating it', () => {
      expect(findNoAgentsGlAlert().props()).toMatchObject({
        title: i18n.invalidProjectAlert.title,
        variant: 'danger',
        dismissible: false,
      });
    });

    it('does not display cluster agents form select group', () => {
      expect(findClusterAgentsFormGroup().exists()).toBe(false);
    });

    it('does not display devfile ref field', () => {
      expect(findDevfileRefField().exists()).toBe(false);
    });

    it('does not display devfile path field', () => {
      expect(findDevfilePathField().exists()).toBe(false);
    });

    it('does not display max hours before termination field', () => {
      expect(findMaxHoursBeforeTerminationField().exists()).toBe(false);
    });
  });

  describe('when a project has cluster agents', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({ clusterAgents: clusterAgentsFixture });
    });

    it('does not display danger alert', () => {
      expect(findNoAgentsGlAlert().exists()).toBe(false);
    });

    it('displays cluster agents form select group', () => {
      expect(findClusterAgentsFormGroup().exists()).toBe(true);
    });

    it('populates cluster agents form select with cluster agents', () => {
      expect(findClusterAgentsFormSelect().props().options).toBe(clusterAgentsFixture);
    });
  });

  describe('when a project and a cluster agent are selected', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({
        clusterAgents: clusterAgentsFixture,
      });
      await selectClusterAgent();
    });

    it('enables create workspace button', () => {
      expect(findCreateWorkspaceButton().props().disabled).toBe(false);
    });

    it('populates devfile ref selector with project ID', () => {
      expect(findDevfileRefRefSelector().props().projectId).toBe(projectId);
    });

    describe('devfile ref field', () => {
      it('renders parts', () => {
        expect(findDevfileRefFieldParts()).toEqual({
          label: 'Git reference',
          icon: 'information-o',
          iconTooltip: 'The branch, tag, or commit hash GitLab uses to create your workspace.',
        });
      });
    });

    describe('devfile path field', () => {
      it('renders parts', () => {
        expect(findDevfilePathFieldParts()).toEqual({
          inputPrepend: 'gitlab-org / gitlab /',
          inputPlaceholder: 'Path to devfile',
          label: 'Devfile location',
          popoverLinkHref: devfileHelpPath,
          popoverLinkText: 'Learn more.',
          popoverText: expect.stringMatching(
            `${i18n.form.devfileLocation.contentParagraph1} ${i18n.form.devfileLocation.contentParagraph2}`,
          ),
        });
      });
    });

    describe('max hours before termination field', () => {
      it('renders parts', () => {
        expect(findMaxHoursBeforeTerminationFieldParts()).toEqual({
          label: 'Workspace automatically terminates after',
          inputAppendText: 'hours',
        });
      });
    });

    it('renders workspace variables component', () => {
      expect(findWorkspaceVariables().props()).toMatchObject({
        variables: [],
        showValidations: false,
      });
    });

    describe('when selecting a project again', () => {
      beforeEach(async () => {
        await selectProject({ nameWithNamespace: 'New Project', fullPath: 'new-project' });
      });

      it('cleans the selected cluster agent', () => {
        expect(findClusterAgentsFormGroup().exists()).toBe(false);
      });
    });

    describe('when clicking Create Workspace button', () => {
      it('submits workspaceCreate mutation', async () => {
        const maxHoursBeforeTermination = 10;
        findMaxHoursBeforeTerminationInput().vm.$emit(
          'input',
          maxHoursBeforeTermination.toString(),
        );

        const devfileRef = 'mybranch';
        findDevfileRefRefSelector().vm.$emit('input', devfileRef);

        const devfilePath = 'path/to/mydevfile.yaml';
        findDevfilePathInput().vm.$emit('input', devfilePath);

        await nextTick();
        await submitCreateWorkspaceForm();

        expect(workspaceCreateMutationHandler).toHaveBeenCalledWith({
          input: {
            clusterAgentId: selectedClusterAgentIDFixture,
            projectId: projectGid,
            editor: DEFAULT_EDITOR,
            desiredState: DEFAULT_DESIRED_STATE,
            devfilePath,
            maxHoursBeforeTermination,
            devfileRef,
            variables: findWorkspaceVariables().props().variables,
          },
        });
      });

      it('sets Create Workspace button as loading', async () => {
        await submitCreateWorkspaceForm();

        expect(findCreateWorkspaceButton().props().loading).toBe(true);
      });

      it('displays workspace variables validations', async () => {
        expect(findWorkspaceVariables().props().showValidations).toBe(false);

        await submitCreateWorkspaceForm();

        expect(findWorkspaceVariables().props().showValidations).toBe(true);
      });

      describe('when workspace variables are not valid', () => {
        it('does not submit the Create Workspace mutation', async () => {
          const variables = [
            {
              key: '',
              value: '',
              type: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
              valid: false,
            },
          ];

          await findWorkspaceVariables().vm.$emit('input', variables);

          await submitCreateWorkspaceForm();

          expect(workspaceCreateMutationHandler).not.toHaveBeenCalled();
        });
      });

      describe('when the workspaceCreate mutation succeeds', () => {
        it('when workspaces are not previously cached, does not update cache', async () => {
          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(readCachedWorkspaces()).toBeUndefined();
        });

        it('when workspaces are previously cached, updates cache', async () => {
          const originalWorkspace = WORKSPACE_QUERY_RESULT.data.workspace;
          writeCachedWorkspaces([originalWorkspace]);

          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(readCachedWorkspaces()).toEqual([
            WORKSPACE_CREATE_MUTATION_RESULT.data.workspaceCreate.workspace,
            originalWorkspace,
          ]);
        });

        it('redirects the user to the workspaces list', async () => {
          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(mockRouter.push).toHaveBeenCalledWith(ROUTES.index);
        });
      });

      describe('when the workspaceCreate mutation returns an error response', () => {
        it('displays an alert that contains the error response', async () => {
          const customMutationResponse = cloneDeep(WORKSPACE_CREATE_MUTATION_RESULT);
          const error = 'error response';

          customMutationResponse.data.workspaceCreate.workspace = null;
          customMutationResponse.data.workspaceCreate.errors.push(error);

          workspaceCreateMutationHandler.mockReset();
          workspaceCreateMutationHandler.mockResolvedValueOnce(customMutationResponse);

          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(findCreateWorkspaceErrorGlAlert().text()).toContain(error);
        });
      });

      describe('when the workspaceCreate mutation fails', () => {
        beforeEach(async () => {
          workspaceCreateMutationHandler.mockReset();
          workspaceCreateMutationHandler.mockRejectedValueOnce(new Error());

          await submitCreateWorkspaceForm();
          await waitForPromises();
        });

        it('logs error', () => {
          expect(logError).toHaveBeenCalled();
        });

        it('sets Create Workspace button as not loading', () => {
          expect(findCreateWorkspaceButton().props().loading).toBe(false);
        });

        it('displays alert indicating that creating a workspace failed', () => {
          expect(findCreateWorkspaceErrorGlAlert().text()).toContain(
            i18n.createWorkspaceFailedMessage,
          );
        });

        describe('when dismissing the create workspace error alert', () => {
          it('hides the workspace error alert', async () => {
            findCreateWorkspaceErrorGlAlert().vm.$emit('dismiss');
            await nextTick();

            expect(findCreateWorkspaceErrorGlAlert().exists()).toBe(false);
          });
        });
      });
    });
  });

  describe('when fetching project details fails', () => {
    beforeEach(() => {
      createWrapper();

      wrapper.findComponent(GetProjectDetailsQuery).vm.$emit('error');
    });

    it('displays alert indicating that fetching project details failed', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: i18n.fetchProjectDetailsFailedMessage });
    });
  });

  describe('fixed elements', () => {
    beforeEach(async () => {
      createWrapper();

      await waitForPromises();
    });
  });

  describe('when selecting a project via URL', () => {
    const projectQueryParam = 'project';

    beforeEach(() => {
      mockRouter.currentRoute.query = { project: projectQueryParam };
      createWrapper();
    });

    it('fetches project details for the project specified in the URL', () => {
      expect(findGetProjectDetailsQuery().props().projectFullPath).toBe(projectQueryParam);
    });
  });

  describe('when receiving project details without a selected project', () => {
    it('populates the selected project with the data provided by the project details', async () => {
      const nameWithNamespace = 'project - new-project';
      const fullPath = 'project/new-project';

      createWrapper();

      emitGetProjectDetailsQueryResult({ nameWithNamespace, fullPath });

      await nextTick();

      expect(findSearchProjectsListbox().props().value).toEqual({ nameWithNamespace, fullPath });
    });
  });
});
