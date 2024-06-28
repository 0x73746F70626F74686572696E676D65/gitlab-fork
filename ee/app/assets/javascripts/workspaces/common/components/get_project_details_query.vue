<script>
import { uniqBy } from 'lodash';
import { logError } from '~/lib/logger';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { joinPaths } from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getProjectDetailsQuery from '../graphql/queries/get_project_details.query.graphql';
import getGroupClusterAgentsQuery from '../graphql/queries/get_group_cluster_agents.query.graphql';
import getRemoteDevelopmentClusterAgents from '../graphql/queries/get_remote_development_cluster_agents.query.graphql';

export default {
  mixins: [glFeatureFlagMixin()],
  props: {
    projectFullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    projectDetails: {
      query: getProjectDetailsQuery,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
        };
      },
      skip() {
        return !this.projectFullPath;
      },
      update() {
        return [];
      },
      error(error) {
        logError(error);
      },
      async result(result) {
        if (result.error || !result.data.project) {
          this.$emit('error');
          return;
        }

        const { nameWithNamespace, repository, group, id } = result.data.project;

        const rootRef = repository ? repository.rootRef : null;

        if (!group) {
          // Guard clause: do not attempt to find agents if project does not have a group
          this.$emit('result', {
            id,
            fullPath: this.projectFullPath,
            nameWithNamespace,
            clusterAgents: [],
            rootRef,
          });
          return;
        }

        const { clusterAgents, errors } =
          (await this.fetchRemoteDevelopmentNamespaceAgentAuthorizationFeatureFlag(group.id))
            ? await this.fetchRemoteDevelopmentClusterAgents(group.fullPath)
            : await this.fetchClusterAgentsForGroupHierarchy(group.fullPath);

        if (Array.isArray(errors) && errors.length) {
          errors.forEach((error) => logError(error));
          this.$emit('error');
          return;
        }

        this.$emit('result', {
          id,
          fullPath: this.projectFullPath,
          nameWithNamespace,
          clusterAgents,
          rootRef,
        });
      },
    },
  },
  methods: {
    async fetchRemoteDevelopmentNamespaceAgentAuthorizationFeatureFlag(namespaceId) {
      const namespaceIid = getIdFromGraphQLId(namespaceId);
      const path = joinPaths(
        gon.relative_url_root || '',
        '/-/remote_development/workspaces_feature_flag',
      );
      return axios
        .get(path, {
          params: {
            flag: 'remote_development_namespace_agent_authorization',
            namespace_id: namespaceIid,
          },
        })
        .then(({ data }) => data.enabled);
    },

    async fetchRemoteDevelopmentClusterAgents(namespace) {
      try {
        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const { data, error } = await this.$apollo.query({
          query: getRemoteDevelopmentClusterAgents,
          variables: { namespace },
        });

        if (error) {
          // NOTE: It seems to be impossible to have test coverage for this line
          //       with the current version of mock-apollo-client. Any type of
          //       mock error is always thrown and caught below instead of
          //       being returned.
          return { errors: [error] };
        }

        return {
          clusterAgents:
            data.namespace?.remoteDevelopmentClusterAgents?.nodes.map(({ id, name, project }) => ({
              value: id,
              text: `${project.nameWithNamespace} / ${name}`,
            })) || [],
        };
      } catch (error) {
        return { errors: [error] };
      }
    },
    async fetchClusterAgentsForGroupHierarchy(groupFullPath) {
      const groupFullPathParts = groupFullPath.split('/') || [];
      const groupPathsFromRoot = groupFullPathParts.map((_, i, arr) =>
        arr.slice(0, i + 1).join('/'),
      );
      const clusterAgentsResponses = await Promise.all(
        groupPathsFromRoot.map((groupPath) => this.fetchClusterAgentForGroup(groupPath)),
      );

      const errors = clusterAgentsResponses.map((response) => response.error).filter(Boolean);

      if (errors.length > 0) {
        return { errors };
      }

      const clusterAgents = clusterAgentsResponses.flatMap((response) => response.result);

      return { clusterAgents: uniqBy(clusterAgents, 'value') };
    },
    async fetchClusterAgentForGroup(groupPath) {
      try {
        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const { data, error } = await this.$apollo.query({
          query: getGroupClusterAgentsQuery,
          variables: { groupPath },
        });

        if (error) {
          // NOTE: It seems to be impossible to have test coverage for this line
          //       with the current version of mock-apollo-client. Any type of
          //       mock error is always thrown and caught below instead of
          //       being returned.
          return { error };
        }

        return {
          result:
            data.group?.clusterAgents?.nodes.map(({ id, name, project }) => ({
              value: id,
              text: `${project.nameWithNamespace} / ${name}`,
            })) || [],
        };
      } catch (error) {
        return { error };
      }
    },
  },
  render() {
    return this.$scopedSlots.default?.();
  },
};
</script>
