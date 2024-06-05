import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { logError } from '~/lib/logger';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ToggleAgentMappingStatusMutation from 'ee_component/workspaces/agent_mapping/components/toggle_agent_mapping_status_mutation.vue';
import createClusterAgentMappingMutation from 'ee/workspaces/agent_mapping/graphql/mutations/create_cluster_agent_mapping.mutation.graphql';
import deleteClusterAgentMappingMutation from 'ee/workspaces/agent_mapping/graphql/mutations/delete_cluster_agent_mapping.mutation.graphql';
import getAgentsWithAuthorizationStatusQuery from 'ee/workspaces/agent_mapping/graphql/queries/get_agents_with_mapping_status.query.graphql';
import {
  CREATE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
  DELETE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
  GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT,
  MAPPED_CLUSTER_AGENT,
  NAMESPACE_ID,
  UNMAPPED_CLUSTER_AGENT,
} from '../../mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('workspaces/agent_mapping/components/toggle_agent_mapping_status_mutation', () => {
  let executeMutationFn;
  let loadingStatus;
  let apolloProvider;
  let createClusterAgentMappingMutationHandler;
  let deleteClusterAgentMappingMutationHandler;
  let wrapper;
  const namespace = 'foo/bar';

  const setupApolloProvider = () => {
    createClusterAgentMappingMutationHandler = jest
      .fn()
      .mockResolvedValueOnce(CREATE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT);
    deleteClusterAgentMappingMutationHandler = jest
      .fn()
      .mockResolvedValueOnce(DELETE_CLUSTER_AGENT_MAPPING_MUTATION_RESULT);

    apolloProvider = createMockApollo([
      [createClusterAgentMappingMutation, createClusterAgentMappingMutationHandler],
      [deleteClusterAgentMappingMutation, deleteClusterAgentMappingMutationHandler],
    ]);

    apolloProvider.clients.defaultClient.writeQuery({
      query: getAgentsWithAuthorizationStatusQuery,
      variables: {
        namespace,
      },
      data: GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT.data,
    });
  };

  const readRemoteDevelopmentClusterAgentsFromQueryCache = () => {
    const apolloClient = apolloProvider.clients.defaultClient;
    const result = apolloClient.readQuery({
      query: getAgentsWithAuthorizationStatusQuery,
      variables: {
        namespace,
      },
    });

    return result?.group.remoteDevelopmentClusterAgents.nodes;
  };

  const buildWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ToggleAgentMappingStatusMutation, {
      apolloProvider,
      propsData: {
        namespaceId: NAMESPACE_ID,
        ...propsData,
      },
      provide: {
        namespace,
      },
      scopedSlots: {
        default(props) {
          executeMutationFn = props.execute;
          loadingStatus = props.loading;
          return this.$createElement('div');
        },
      },
    });
  };

  beforeEach(() => {
    setupApolloProvider();
  });

  describe('when executing mutation', () => {
    it('sets loading status as loading', async () => {
      buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT } });

      expect(loadingStatus).toBe(false);

      executeMutationFn();

      await nextTick();

      expect(loadingStatus).toBe(true);
    });

    describe(`given the agent status is ${MAPPED_CLUSTER_AGENT.mappingStatus}`, () => {
      beforeEach(async () => {
        buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT } });

        executeMutationFn();

        await nextTick();
      });

      it('executes deleteClusterAgentMappingMutation', () => {
        expect(deleteClusterAgentMappingMutationHandler).toHaveBeenCalledWith({
          input: {
            clusterAgentId: MAPPED_CLUSTER_AGENT.id,
            namespaceId: NAMESPACE_ID,
          },
        });
      });

      it('removes agent from the remoteDevelopmentClusterAgents collection', () => {
        const agents = readRemoteDevelopmentClusterAgentsFromQueryCache();

        expect(agents.some((agent) => agent.id === MAPPED_CLUSTER_AGENT.id)).toBe(false);
      });
    });

    describe(`given the agent status is ${UNMAPPED_CLUSTER_AGENT.mappingStatus}`, () => {
      beforeEach(async () => {
        buildWrapper({ propsData: { agent: UNMAPPED_CLUSTER_AGENT } });

        executeMutationFn();

        await nextTick();
      });

      it('executes createClusterAgentMappingMutation', () => {
        expect(createClusterAgentMappingMutationHandler).toHaveBeenCalledWith({
          input: {
            clusterAgentId: UNMAPPED_CLUSTER_AGENT.id,
            namespaceId: NAMESPACE_ID,
          },
        });
      });

      it('adds unmapped agents to the remoteDevelopmentClusterAgents collection', () => {
        const agents = readRemoteDevelopmentClusterAgentsFromQueryCache();

        expect(agents.some((agent) => agent.id === UNMAPPED_CLUSTER_AGENT.id)).toBe(true);
      });
    });

    describe('when the mutation fails', () => {
      const error = new Error();

      beforeEach(async () => {
        createClusterAgentMappingMutationHandler.mockReset().mockRejectedValueOnce(error);

        buildWrapper({ propsData: { agent: UNMAPPED_CLUSTER_AGENT } });

        executeMutationFn();

        await nextTick();
        await waitForPromises();
      });

      it('emits error event', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
      });

      it('logs error', () => {
        expect(logError).toHaveBeenCalledWith(error);
      });

      it('captures the exception in Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });
  });
});
