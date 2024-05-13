import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { cloneDeep } from 'lodash';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import getProjectDetailsQuery from 'ee/workspaces/common/graphql/queries/get_project_details.query.graphql';
import getGroupClusterAgentsQuery from 'ee/workspaces/common/graphql/queries/get_group_cluster_agents.query.graphql';
import getRemoteDevelopmentClusterAgentsQuery from 'ee/workspaces/common/graphql/queries/get_remote_development_cluster_agents.query.graphql';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  GET_PROJECT_DETAILS_QUERY_RESULT,
  GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT,
  GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT,
  GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_NO_AGENT,
  GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
  GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_DUPLICATES_ROOTGROUP,
  GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
  GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');

describe('workspaces/common/components/get_project_details_query', () => {
  let getProjectDetailsQueryHandler;
  let getGroupClusterAgentsQueryHandler;
  let getRemoteDevelopmentClusterAgentsQueryHandler;
  let glFeatures;
  let wrapper;
  let mockAxios;

  const projectFullPathFixture = 'gitlab-org/gitlab';
  const WORKSPACES_FEATURE_FLAG_PATH = '/-/remote_development/workspaces_feature_flag';

  const setupGroupClusterAgentsQueryHandler = (groupResponses) => {
    getGroupClusterAgentsQueryHandler.mockImplementation(({ groupPath }) => {
      const matchingResponse = groupResponses.find((x) => x.data.group.fullPath === groupPath);

      if (matchingResponse) {
        return Promise.resolve(matchingResponse);
      }

      return Promise.resolve({
        data: {
          group: null,
        },
      });
    });
  };

  const setupRemoteDevelopmentClusterAgentsQueryHandler = (responses) => {
    getRemoteDevelopmentClusterAgentsQueryHandler.mockResolvedValueOnce(responses);
  };

  const buildWrapper = async ({ projectFullPath = projectFullPathFixture } = {}) => {
    const apolloProvider = createMockApollo([
      [getProjectDetailsQuery, getProjectDetailsQueryHandler],
      [getGroupClusterAgentsQuery, getGroupClusterAgentsQueryHandler],
      [getRemoteDevelopmentClusterAgentsQuery, getRemoteDevelopmentClusterAgentsQueryHandler],
    ]);

    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMountExtended(GetProjectDetailsQuery, {
      apolloProvider,
      provide: {
        glFeatures,
        workspacesFeatureFlagPath: WORKSPACES_FEATURE_FLAG_PATH,
      },
      propsData: {
        projectFullPath,
      },
    });

    await waitForPromises();
  };

  const transformGroupClusterAgentGraphQLResultToClusterAgents = (clusterAgentsGraphQLResult) =>
    clusterAgentsGraphQLResult.data.group.clusterAgents.nodes.map(({ id, name, project }) => ({
      text: `${project.nameWithNamespace} / ${name}`,
      value: id,
    }));

  const transformRemoveDevelopmentClusterAgentGraphQLResultToClusterAgents = (
    clusterAgentsGraphQLResult,
  ) =>
    clusterAgentsGraphQLResult.data.namespace.remoteDevelopmentClusterAgents.nodes.map(
      ({ id, name, project }) => ({
        text: `${project.nameWithNamespace} / ${name}`,
        value: id,
      }),
    );

  beforeEach(() => {
    getProjectDetailsQueryHandler = jest.fn();
    getGroupClusterAgentsQueryHandler = jest.fn();
    getRemoteDevelopmentClusterAgentsQueryHandler = jest.fn();

    logError.mockReset();

    getProjectDetailsQueryHandler.mockResolvedValueOnce(GET_PROJECT_DETAILS_QUERY_RESULT);
    setupGroupClusterAgentsQueryHandler([]);
  });

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
    mockAxios.onGet(WORKSPACES_FEATURE_FLAG_PATH).reply(HTTP_STATUS_OK, { enabled: false });
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('when project full path is provided', () => {
    it('executes get_project_details query', async () => {
      await buildWrapper();

      expect(getProjectDetailsQueryHandler).toHaveBeenCalledWith({
        projectFullPath: projectFullPathFixture,
      });
    });
  });

  describe('when both the root group and subgroup return an agent', () => {
    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);
    });

    it('executes get_group_cluster_agents query', async () => {
      await buildWrapper();

      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
      });
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org/subgroup',
      });
    });

    it('emits result event with fetched cluster agents, project id, project group, and root files', async () => {
      await buildWrapper();

      const expectedClusterAgents = [
        ...transformGroupClusterAgentGraphQLResultToClusterAgents(
          GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT,
        ),
        ...transformGroupClusterAgentGraphQLResultToClusterAgents(
          GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
        ),
      ];

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: expectedClusterAgents,
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });
  });

  describe('when only the subgroup returns an agent', () => {
    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);
    });

    it('executes get_group_cluster_agents query', async () => {
      await buildWrapper();

      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
      });
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org/subgroup',
      });
    });

    it('emits result event with fetched cluster agents, project id, project group, and root files', async () => {
      await buildWrapper();

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: transformGroupClusterAgentGraphQLResultToClusterAgents(
          GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
        ),
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });
  });

  describe('when subgroup returns agent and root group returns null', () => {
    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);
    });

    it('emits result with just subgroup items', async () => {
      await buildWrapper();

      await waitForPromises();

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: [
          {
            text: 'GitLab Org / Subgroup / GitLab / subgroup-agent',
            value: 'gid://gitlab/Clusters::Agent/2',
          },
        ],
        fullPath: 'gitlab-org/gitlab',
        id: 'gid://gitlab/Project/1',
        nameWithNamespace: 'GitLab Org / Subgroup / GitLab',
        rootRef: 'main',
      });
    });
  });

  describe('when the subgroup returns a duplicate agent from the root group', () => {
    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_DUPLICATES_ROOTGROUP,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);
    });

    it('executes get_group_cluster_agents query', async () => {
      await buildWrapper();

      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org',
      });
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org/subgroup',
      });
    });

    it('emits result event with fetched cluster agents, project id, project group, and root files with no duplicates', async () => {
      await buildWrapper();

      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: [
          ...transformGroupClusterAgentGraphQLResultToClusterAgents(
            GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_ONE_AGENT,
          ),
          ...transformGroupClusterAgentGraphQLResultToClusterAgents(
            GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_ONE_AGENT,
          ),
        ],
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });

    describe('when the project is null', () => {
      beforeEach(() => {
        const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

        customMockData.data.project = null;

        getProjectDetailsQueryHandler.mockReset();
        getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);
      });

      it('emits error event', async () => {
        await buildWrapper();

        expect(wrapper.emitted('error')).toEqual([[]]);
      });
    });
  });

  describe('when the project does not have a repository', () => {
    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_NO_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);

      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

      customMockData.data.project.repository = null;

      getProjectDetailsQueryHandler.mockReset();
      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);
    });

    it('emits result event with rootRef null', async () => {
      await buildWrapper();

      expect(wrapper.emitted('result')[0][0]).toMatchObject({
        rootRef: null,
      });
    });
  });

  describe('when project full path is not provided', () => {
    it('does not execute get_project_details query', async () => {
      // noinspection JSCheckFunctionSignatures -- This is incorrectly assuming the projectFullPath type is String due to its default value in the declaration
      await buildWrapper({ projectFullPath: null });

      expect(getProjectDetailsQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('when a project does not belong to a group', () => {
    beforeEach(async () => {
      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

      customMockData.data.project.group = null;

      getProjectDetailsQueryHandler.mockReset();
      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);

      await buildWrapper();
    });

    it('does not execute the getGroupClusterAgents query', () => {
      expect(getProjectDetailsQueryHandler).toHaveBeenCalled();
      expect(getGroupClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });

    it('emits result event with the project data', () => {
      expect(wrapper.emitted('result')[0][0]).toEqual({
        clusterAgents: [],
        id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
        rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
        nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        fullPath: projectFullPathFixture,
      });
    });
  });

  describe('when the project full path changes', () => {
    it('fetches agents for the entire project group hierarchy', async () => {
      const customMockData = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);

      await buildWrapper();

      // Called once for each part in group path
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);

      customMockData.data.project.group.fullPath = 'new';

      getProjectDetailsQueryHandler.mockResolvedValueOnce(customMockData);

      await wrapper.setProps({ projectFullPath: 'new/path' });

      await waitForPromises();

      // Once more because group.fullPath only has 1 part now
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(3);
    });
  });

  describe('when the project full path changes from group to not group', () => {
    beforeEach(async () => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_NO_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);

      await waitForPromises();
    });

    it('emits empty clusters', async () => {
      const projectFullPath = 'new/path';

      await buildWrapper();

      // Called once for each part in group path
      expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);

      const projectWithoutGroup = cloneDeep(GET_PROJECT_DETAILS_QUERY_RESULT);
      projectWithoutGroup.data.project.group = null;
      getProjectDetailsQueryHandler.mockResolvedValueOnce(projectWithoutGroup);

      // assert that we've only emitted once
      expect(wrapper.emitted('result')).toHaveLength(1);
      await wrapper.setProps({ projectFullPath });

      await waitForPromises();

      // assert against the last emitted result
      expect(wrapper.emitted('result')).toHaveLength(2);
      expect(wrapper.emitted('result')[1]).toEqual([
        {
          clusterAgents: [],
          id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
          rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
          fullPath: projectFullPath,
          nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        },
      ]);
    });
  });

  describe.each`
    queryName                       | queryHandlerFactory
    ${'getProjectDetailsQuery'}     | ${() => getProjectDetailsQueryHandler}
    ${'getGroupClusterAgentsQuery'} | ${() => getGroupClusterAgentsQueryHandler}
  `('when the $queryName query fails', ({ queryHandlerFactory }) => {
    const error = new Error();

    beforeEach(() => {
      const mockedClusterAgentResponses = [
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_ROOTGROUP_NO_AGENT,
        GET_GROUP_CLUSTER_AGENTS_QUERY_RESULT_SUBGROUP_NO_AGENT,
      ];
      setupGroupClusterAgentsQueryHandler(mockedClusterAgentResponses);

      const queryHandler = queryHandlerFactory();

      queryHandler.mockReset();
      queryHandler.mockRejectedValueOnce(error);
    });

    it('logs the error', async () => {
      expect(logError).not.toHaveBeenCalled();

      await buildWrapper();

      expect(logError).toHaveBeenCalledWith(error);
    });

    it('does not emit result event', async () => {
      await buildWrapper();

      expect(wrapper.emitted('result')).toBe(undefined);
    });

    it('emits error event', async () => {
      await buildWrapper();

      expect(wrapper.emitted('error')).toEqual([[]]);
    });
  });

  describe('when remote_development_namespace_agent_authorization feature flag is enabled', () => {
    beforeEach(() => {
      mockAxios.onGet(WORKSPACES_FEATURE_FLAG_PATH).reply(HTTP_STATUS_OK, { enabled: true });
    });

    describe('when the project belongs to a group', () => {
      beforeEach(async () => {
        await buildWrapper();
      });

      it('executes getRemoteDevelopmentClusterAgents query', () => {
        expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledTimes(1);
        expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledWith({
          namespace: 'gitlab-org/subgroup',
        });
      });

      it('does not execute getRemoteDevelopmentClusterAgents', () => {
        expect(getGroupClusterAgentsQueryHandler).toHaveBeenCalledTimes(0);
      });
    });

    describe('when getRemoteDevelopmentClusterAgents query contains one or more cluster agents', () => {
      beforeEach(async () => {
        setupRemoteDevelopmentClusterAgentsQueryHandler(
          GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
        );
        await buildWrapper();
      });

      it('emits result event with the cluster agents', async () => {
        await waitForPromises();

        expect(wrapper.emitted('result')[0][0]).toEqual({
          clusterAgents: transformRemoveDevelopmentClusterAgentGraphQLResultToClusterAgents(
            GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
          ),
          id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
          rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
          fullPath: projectFullPathFixture,
          nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        });
      });
    });

    describe('when getRemoteDevelopmentClusterAgents query does not contain cluster agents', () => {
      beforeEach(async () => {
        setupRemoteDevelopmentClusterAgentsQueryHandler(
          GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_NO_AGENTS,
        );
        await buildWrapper();
      });

      it('emits result event with the cluster agents', async () => {
        await waitForPromises();

        expect(wrapper.emitted('result')[0][0]).toEqual({
          clusterAgents: [],
          id: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id,
          rootRef: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.repository.rootRef,
          fullPath: projectFullPathFixture,
          nameWithNamespace: GET_PROJECT_DETAILS_QUERY_RESULT.data.project.nameWithNamespace,
        });
      });
    });

    describe('when getRemoteDevelopmentClusterAgents query fails', () => {
      const error = new Error();

      beforeEach(() => {
        getRemoteDevelopmentClusterAgentsQueryHandler.mockReset();
        getRemoteDevelopmentClusterAgentsQueryHandler.mockRejectedValueOnce(error);
      });

      it('logs the error', async () => {
        expect(logError).not.toHaveBeenCalled();

        await buildWrapper();

        expect(logError).toHaveBeenCalledWith(error);
      });

      it('does not emit result event', async () => {
        await buildWrapper();

        expect(wrapper.emitted('result')).toBe(undefined);
      });

      it('emits error event', async () => {
        await buildWrapper();

        expect(wrapper.emitted('error')).toEqual([[]]);
      });
    });
  });
});
