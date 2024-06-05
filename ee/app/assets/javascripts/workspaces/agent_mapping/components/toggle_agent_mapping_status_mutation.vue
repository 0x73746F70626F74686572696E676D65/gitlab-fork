<script>
import produce from 'immer';
import { logError } from '~/lib/logger';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createClusterAgentMappingMutation from '../graphql/mutations/create_cluster_agent_mapping.mutation.graphql';
import deleteClusterAgentMappingMutation from '../graphql/mutations/delete_cluster_agent_mapping.mutation.graphql';
import getAgentsWithAuthorizationStatusQuery from '../graphql/queries/get_agents_with_mapping_status.query.graphql';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';

const MAPPING_STATUS_MUTATION = {
  [AGENT_MAPPING_STATUS_MAPPED]: deleteClusterAgentMappingMutation,
  [AGENT_MAPPING_STATUS_UNMAPPED]: createClusterAgentMappingMutation,
};

export default {
  inject: {
    namespace: {
      default: '',
    },
  },
  props: {
    namespaceId: {
      type: String,
      required: true,
    },
    agent: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
    };
  },
  methods: {
    async execute() {
      const { agent, namespace } = this;
      const mutation = MAPPING_STATUS_MUTATION[agent.mappingStatus];

      try {
        this.loading = true;

        await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              clusterAgentId: this.agent.id,
              namespaceId: this.namespaceId,
            },
          },
          update(store) {
            store.updateQuery(
              {
                query: getAgentsWithAuthorizationStatusQuery,
                variables: { namespace },
              },
              (sourceData) =>
                produce(sourceData, (draftData) => {
                  const { remoteDevelopmentClusterAgents } = draftData.group;
                  const { nodes } = remoteDevelopmentClusterAgents;

                  if (agent.mappingStatus === AGENT_MAPPING_STATUS_MAPPED) {
                    remoteDevelopmentClusterAgents.nodes = nodes.filter(
                      (node) => node.id !== agent.id,
                    );
                  } else {
                    remoteDevelopmentClusterAgents.nodes.push(agent);
                  }
                }),
            );
          },
        });
      } catch (e) {
        Sentry.captureException(e);
        logError(e);
        this.$emit('error', e);
      } finally {
        this.loading = false;
      }
    },
  },
  render() {
    return this.$scopedSlots.default?.({ loading: this.loading, execute: this.execute });
  },
};
</script>
