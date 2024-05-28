<script>
import { logError } from '~/lib/logger';
import getAgentsWithAuthorizationStatusQuery from '../graphql/queries/get_agents_with_mapping_status.query.graphql';
import { AGENT_MAPPING_STATUS_MAPPED, AGENT_MAPPING_STATUS_UNMAPPED } from '../constants';

export default {
  props: {
    namespace: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    getGroupClusterAgents: {
      query: getAgentsWithAuthorizationStatusQuery,
      variables() {
        return {
          namespace: this.namespace,
        };
      },
      skip() {
        return !this.namespace;
      },
      update() {
        return [];
      },
      error(error) {
        logError(error);
      },
      result(result) {
        if (result.error) {
          this.$emit('error', { error: result.error });
          return;
        }

        const {
          remoteDevelopmentClusterAgents,
          clusterAgents,
          id: namespaceId,
        } = result.data.group;

        const agents =
          clusterAgents?.nodes.map(({ id, name }) => {
            const mappingStatus = remoteDevelopmentClusterAgents?.nodes.some(
              (agent) => agent.id === id,
            )
              ? AGENT_MAPPING_STATUS_MAPPED
              : AGENT_MAPPING_STATUS_UNMAPPED;

            return {
              id,
              name,
              mappingStatus,
            };
          }) || [];

        this.$emit('result', { namespaceId, agents });
      },
    },
  },
  render() {
    return this.$scopedSlots.default?.({ loading: this.$apollo.loading });
  },
};
</script>
