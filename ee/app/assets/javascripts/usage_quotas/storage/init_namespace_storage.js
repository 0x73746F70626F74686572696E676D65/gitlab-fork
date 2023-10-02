import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { storageTypeHelpPaths as helpLinks } from '~/usage_quotas/storage/constants';
import { PROJECT_ENFORCEMENT_TYPE } from './constants';
import NamespaceStorageApp from './components/namespace_storage_app.vue';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-storage-counter-app');

  if (!el) {
    return false;
  }

  const {
    namespaceId,
    namespacePath,
    userNamespace,
    defaultPerPage,
    namespacePlanName,
    namespacePlanStorageIncluded,
    purchaseStorageUrl,
    buyAddonTargetAttr,
    enforcementType,
    totalRepositorySizeExcess,
  } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'NamespaceStorageApp',
    provide: {
      namespaceId,
      namespacePath,
      userNamespace: parseBoolean(userNamespace),
      defaultPerPage: Number(defaultPerPage),
      namespacePlanName,
      namespacePlanStorageIncluded: namespacePlanStorageIncluded
        ? Number(namespacePlanStorageIncluded)
        : 0,
      purchaseStorageUrl,
      buyAddonTargetAttr,
      enforcementType,
      totalRepositorySizeExcess: totalRepositorySizeExcess && Number(totalRepositorySizeExcess),
      isUsingProjectEnforcement: enforcementType === PROJECT_ENFORCEMENT_TYPE,
      helpLinks,
    },
    render(createElement) {
      return createElement(NamespaceStorageApp);
    },
  });
};
