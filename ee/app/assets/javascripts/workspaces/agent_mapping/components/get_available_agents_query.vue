<script>
import { logError } from '~/lib/logger';
import getRemoteDevelopmentClusterAgentsQuery from 'ee/workspaces/common/graphql/queries/get_remote_development_cluster_agents.query.graphql';

export default {
  props: {
    namespace: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    getRemoteDevelopmentClusterAgents: {
      query: getRemoteDevelopmentClusterAgentsQuery,
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

        const agents =
          result.data.namespace?.remoteDevelopmentClusterAgents?.nodes.map(({ id, name }) => ({
            id,
            name,
          })) || [];

        this.$emit('result', { agents });
      },
    },
  },
  render() {
    return this.$scopedSlots.default?.({ loading: this.$apollo.loading });
  },
};
</script>
