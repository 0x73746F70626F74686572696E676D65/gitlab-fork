import Vue from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import getProjectsDetailsQuery from 'ee/workspaces/common/graphql/queries/get_projects_details.query.graphql';
import userWorkspacesListQuery from 'ee/workspaces/common/graphql/queries/user_workspaces_list.query.graphql';
import App from 'ee/workspaces/user/pages/app.vue';
import WorkspacesList from 'ee/workspaces/user/pages/list.vue';
import createRouter from 'ee/workspaces/user/router/index';
import CreateWorkspace from 'ee/workspaces/user/pages/create.vue';
import { ROUTES } from 'ee/workspaces/user/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  GET_PROJECTS_DETAILS_QUERY_RESULT,
  USER_WORKSPACES_LIST_QUERY_EMPTY_RESULT,
} from '../../mock_data';

Vue.use(VueRouter);
Vue.use(VueApollo);

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';
const DEFAULT_MAX_HOURS_BEFORE_TERMINATION = 42;

describe('workspaces/router/index.js', () => {
  let router;
  let wrapper;

  beforeEach(() => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    router = createRouter(ROUTES.index);
  });

  afterEach(() => {
    window.location.hash = '';
  });

  const mountApp = async (route = ROUTES.index) => {
    await router.push(route);

    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mountExtended(App, {
      router,
      apolloProvider: createMockApollo([
        [
          userWorkspacesListQuery,
          jest.fn().mockResolvedValue(USER_WORKSPACES_LIST_QUERY_EMPTY_RESULT),
        ],
        [
          getProjectsDetailsQuery,
          jest.fn().mockResolvedValueOnce(GET_PROJECTS_DETAILS_QUERY_RESULT),
        ],
      ]),
      provide: {
        emptyStateSvgPath: SVG_PATH,
        defaultMaxHoursBeforeTermination: DEFAULT_MAX_HOURS_BEFORE_TERMINATION,
      },
      stubs: {
        SearchProjectsListbox: {
          template: '<div></div>',
        },
      },
    });
  };
  const findWorkspacesListPage = () => wrapper.findComponent(WorkspacesList);
  const findCreateWorkspacePage = () => wrapper.findComponent(CreateWorkspace);
  const findNewWorkspaceButton = () => wrapper.findByRole('link', { name: /New workspace/ });
  const findCreateWorkspaceCancelButton = () => wrapper.findByRole('link', { name: /Cancel/ });

  describe('root path', () => {
    beforeEach(async () => {
      await mountApp();
    });

    it('renders WorkspacesList on route /', () => {
      expect(findWorkspacesListPage().exists()).toBe(true);
    });

    it('navigates to /create when clicking New workspace button', async () => {
      await findNewWorkspaceButton().trigger('click');

      expect(findCreateWorkspacePage().exists()).toBe(true);
    });
  });

  describe('create path', () => {
    beforeEach(async () => {
      await mountApp(ROUTES.new);
    });

    it(`renders CreateWorkspace on route ${ROUTES.new}`, () => {
      expect(findCreateWorkspacePage().exists()).toBe(true);
    });

    it('navigates to / when clicking Cancel button', async () => {
      await findCreateWorkspaceCancelButton().trigger('click');

      expect(findWorkspacesListPage().exists()).toBe(true);
    });
  });
});
