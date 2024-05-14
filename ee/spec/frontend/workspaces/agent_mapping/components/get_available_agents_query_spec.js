import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { logError } from '~/lib/logger';
import getRemoteDevelopmentClusterAgentsQuery from 'ee/workspaces/common/graphql/queries/get_remote_development_cluster_agents.query.graphql';
import GetAvailableAgentsQuery from 'ee/workspaces/agent_mapping/components/get_available_agents_query.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');

describe('workspaces/agent_mapping/components/get_available_agents_query.vue', () => {
  let getRemoteDevelopmentClusterAgentsQueryHandler;
  let wrapper;
  const NAMESPACE = 'gitlab-org/gitlab';

  const buildWrapper = async ({ propsData = {}, scopedSlots = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [getRemoteDevelopmentClusterAgentsQuery, getRemoteDevelopmentClusterAgentsQueryHandler],
    ]);

    wrapper = shallowMount(GetAvailableAgentsQuery, {
      apolloProvider,
      propsData: {
        ...propsData,
      },
      scopedSlots: {
        ...scopedSlots,
      },
    });

    await waitForPromises();
  };
  const buildWrapperWithNamespace = () => buildWrapper({ propsData: { namespace: NAMESPACE } });

  const setupRemoteDevelopmentClusterAgentsQueryHandler = (responses) => {
    getRemoteDevelopmentClusterAgentsQueryHandler.mockResolvedValueOnce(responses);
  };

  const transformRemoteDevelopmentClusterAgentGraphQLResultToClusterAgents = (
    clusterAgentsGraphQLResult,
  ) =>
    clusterAgentsGraphQLResult.data.namespace.remoteDevelopmentClusterAgents.nodes.map(
      ({ id, name }) => ({
        name,
        id,
      }),
    );

  beforeEach(() => {
    getRemoteDevelopmentClusterAgentsQueryHandler = jest.fn();
    logError.mockReset();
  });

  it('exposes apollo loading state in the default slot', async () => {
    let loadingState = null;

    await buildWrapper({
      propsData: { namespace: NAMESPACE },
      scopedSlots: {
        default: (props) => {
          loadingState = props.loading;
          return null;
        },
      },
    });

    expect(loadingState).toBe(false);
  });

  describe('when namespace path is provided', () => {
    it('executes getRemoteDevelopmentClusterAgentsQuery query', async () => {
      await buildWrapperWithNamespace();

      expect(getRemoteDevelopmentClusterAgentsQueryHandler).toHaveBeenCalledWith({
        namespace: NAMESPACE,
      });
    });

    describe('when the query is successful', () => {
      beforeEach(() => {
        setupRemoteDevelopmentClusterAgentsQueryHandler(
          GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
        );
      });

      it('triggers result event with the agents list', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('result')).toEqual([
          [
            {
              agents: transformRemoteDevelopmentClusterAgentGraphQLResultToClusterAgents(
                GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
              ),
            },
          ],
        ]);
      });
    });

    describe('when the query fails', () => {
      const error = new Error();

      beforeEach(() => {
        getRemoteDevelopmentClusterAgentsQueryHandler.mockReset();
        getRemoteDevelopmentClusterAgentsQueryHandler.mockRejectedValueOnce(error);
      });

      it('logs the error', async () => {
        expect(logError).not.toHaveBeenCalled();

        await buildWrapperWithNamespace();

        expect(logError).toHaveBeenCalledWith(error);
      });

      it('does not emit result event', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('result')).toBe(undefined);
      });

      it('emits error event', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('error')).toEqual([[{ error }]]);
      });
    });
  });

  describe('when namespace path is not provided', () => {
    it('does not getRemoteDevelopmentClusterAgentsQuery query', async () => {
      setupRemoteDevelopmentClusterAgentsQueryHandler(
        GET_REMOTE_DEVELOPMENT_CLUSTER_AGENTS_QUERY_RESULT_TWO_AGENTS,
      );
      await buildWrapper();

      expect(getRemoteDevelopmentClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });
  });
});
