export const TEST_PROJECT_FULL_PATH = 'group-1/project-1';

export const TEST_PROJECT_ID = '2';

export const createInstanceResponse = (errors = []) => ({
  data: {
    projectInitializeProductAnalytics: {
      project: {
        id: 'gid://gitlab/Project/2',
        fullPath: '',
      },
      errors,
    },
  },
});

export const getTrackingKeyResponse = (trackingKey = null) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      trackingKey,
    },
  },
});

export const getProductAnalyticsStateResponse = (productAnalyticsState = null) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      productAnalyticsState,
    },
  },
});

export const getProductAnalyticsProjectSettingsUpdateResponse = (
  updatedSettings = {
    productAnalyticsConfiguratorConnectionString: null,
    productAnalyticsDataCollectorHost: null,
    cubeApiBaseUrl: null,
    cubeApiKey: null,
  },
  errors = [],
) => ({
  data: {
    productAnalyticsProjectSettingsUpdate: {
      __typename: 'ProductAnalyticsProjectSettingsUpdatePayload',
      errors,
      ...updatedSettings,
    },
  },
});

export const getProjectLevelAnalyticsProviderSettings = () => ({
  productAnalyticsConfiguratorConnectionString: 'https://configurator.example.com',
  productAnalyticsDataCollectorHost: 'https://collector.example.com',
  cubeApiBaseUrl: 'https://cubejs.example.com',
  cubeApiKey: 'abc-123',
});

export const getPartialProjectLevelAnalyticsProviderSettings = () => ({
  productAnalyticsConfiguratorConnectionString: null,
  productAnalyticsDataCollectorHost: null,
  cubeApiBaseUrl: 'https://cubejs.example.com',
  cubeApiKey: 'abc-123',
});

export const getEmptyProjectLevelAnalyticsProviderSettings = () => ({
  productAnalyticsConfiguratorConnectionString: null,
  productAnalyticsDataCollectorHost: null,
  cubeApiBaseUrl: null,
  cubeApiKey: null,
});
