import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { resolvers, cacheConfig } from './graphql/settings';
import getGroupSecretsQuery from './graphql/queries/client/get_group_secrets.query.graphql';
import getProjectSecretsQuery from './graphql/queries/client/get_project_secrets.query.graphql';
import createRouter from './router';

import GroupSecretsApp from './components/group_secrets_app.vue';
import ProjectSecretsApp from './components/project_secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';

import { mockGroupSecretsData, mockProjectSecretsData } from './mock_data';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(resolvers, { cacheConfig }),
});

const initSecretsApp = (el, app, props, basePath) => {
  const router = createRouter(basePath, props);

  injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);

  return new Vue({
    el,
    router,
    name: 'SecretsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(app, { props });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, groupId, basePath } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getGroupSecretsQuery,
    variables: { fullPath: groupPath },
    data: {
      group: {
        id: convertToGraphQLId(TYPENAME_GROUP, groupId),
        fullPath: groupPath,
        secrets: {
          count: mockGroupSecretsData.length,
          nodes: mockGroupSecretsData,
        },
      },
    },
  });

  return initSecretsApp(el, GroupSecretsApp, { groupPath, groupId }, basePath);
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, projectId, basePath } = el.dataset;

  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: getProjectSecretsQuery,
    variables: { fullPath: projectPath },
    data: {
      project: {
        id: convertToGraphQLId(TYPENAME_PROJECT, projectId),
        fullPath: projectPath,
        secrets: {
          count: mockProjectSecretsData.length,
          nodes: mockProjectSecretsData,
        },
      },
    },
  });

  return initSecretsApp(el, ProjectSecretsApp, { projectPath, projectId }, basePath);
};
