import { defaultNamespaceProvideValues } from 'ee_jest/usage_quotas/storage/mock_data';
import {
  mockGetNamespaceStorageGraphQLResponse,
  mockGetProjectListStorageGraphQLResponse,
} from 'jest/usage_quotas/storage/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import getNamespaceStorageQuery from 'ee_else_ce/usage_quotas/storage/queries/namespace_storage.query.graphql';
import getProjectListStorageQuery from 'ee_else_ce/usage_quotas/storage/queries/project_list_storage.query.graphql';
import NamespaceStorageApp from './namespace_storage_app.vue';

const meta = {
  title: 'ee/usage_quotas/storage/namespace_storage_app',
  component: NamespaceStorageApp,
};

export default meta;

const GIBIBYTE = 1024 * 1024 * 1024; // bytes in a gibibyte

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [getNamespaceStorageQuery, () => Promise.resolve(mockGetNamespaceStorageGraphQLResponse)],
      [getProjectListStorageQuery, () => Promise.resolve(mockGetProjectListStorageGraphQLResponse)],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { NamespaceStorageApp },
    apolloProvider,
    provide: {
      ...defaultNamespaceProvideValues,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<namespace-storage-app />',
  });
};

export const SaasWithNamespaceLimits = {
  render: createTemplate(),
};

export const SaasWithNamespaceLimitsLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getProjectListStorageQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const SaasWithProjectLimits = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      totalRepositorySizeExcess: 3 * GIBIBYTE,
    },
  }),
};

export const SaasWithNoLimits = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: false,
      isUsingProjectEnforcementWithNoLimits: true,
      perProjectStorageLimit: 0,
      namespaceStorageLimit: 0,
    },
  }),
};

export const SaasWithNoLimitsInPreEnforcement = {
  render: createTemplate({
    provide: {
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcementWithLimits: false,
      isUsingProjectEnforcementWithNoLimits: true,
      isInNamespaceLimitsPreEnforcement: true,
      totalRepositorySizeExcess: 0,
      namespacePlanStorageIncluded: 0,
    },
  }),
};

export const SaasWithProjectLimitsLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getProjectListStorageQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
      provide: {
        isUsingNamespaceEnforcement: false,
        isUsingProjectEnforcementWithLimits: true,
        isUsingProjectEnforcementWithNoLimits: false,
        totalRepositorySizeExcess: 3 * GIBIBYTE,
      },
    })(...args);
  },
};

export const SaasLoadingError = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => Promise.reject()],
      [getProjectListStorageQuery, () => Promise.reject()],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

const selfManagedDefaultProvide = {
  isUsingProjectEnforcementWithLimits: false,
  isUsingProjectEnforcementWithNoLimits: true,
  isUsingNamespaceEnforcement: false,
  namespacePlanName: null,
  perProjectStorageLimit: 0,
  namespaceStorageLimit: 0,
  purchaseStorageUrl: null,
  buyAddonTargetAttr: null,
};

export const SelfManaged = {
  render: createTemplate({
    provide: {
      ...selfManagedDefaultProvide,
    },
  }),
};

export const SelfManagedWithProjectLimits = {
  render: createTemplate({
    provide: {
      ...selfManagedDefaultProvide,
      isUsingProjectEnforcementWithLimits: true,
      isUsingProjectEnforcementWithNoLimits: false,
      perProjectStorageLimit: 10 * GIBIBYTE,
    },
  }),
};

export const SelfManagedLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getProjectListStorageQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
      provide: {
        ...selfManagedDefaultProvide,
      },
    })(...args);
  },
};
