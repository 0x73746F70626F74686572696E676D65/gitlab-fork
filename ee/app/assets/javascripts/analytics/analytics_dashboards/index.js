import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import {
  convertObjectPropsToCamelCase,
  convertArrayToCamelCase,
  parseBoolean,
} from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import DashboardsApp from './dashboards_app.vue';
import createRouter from './router';
import AnalyticsDashboardsBreadcrumbs from './components/analytics_dashboards_breadcrumbs.vue';

const buildAnalyticsDashboardPointer = (analyticsDashboardPointerJSON = '') => {
  return analyticsDashboardPointerJSON.length
    ? convertObjectPropsToCamelCase(JSON.parse(analyticsDashboardPointerJSON))
    : null;
};

export default () => {
  const el = document.getElementById('js-analytics-dashboards-list-app');

  if (!el) {
    return false;
  }

  const {
    dashboardProject: analyticsDashboardPointerJSON = '',
    canConfigureDashboardsProject,
    canSelectGitlabManagedProvider,
    managedClusterPurchased,
    trackingKey,
    namespaceId,
    namespaceName,
    namespaceFullPath,
    isProject,
    isGroup,
    collectorHost,
    chartEmptyStateIllustrationPath,
    dashboardEmptyStateIllustrationPath,
    analyticsSettingsPath,
    routerBase,
    features,
    rootNamespaceName,
    rootNamespaceFullPath,
    dataSourceClickhouse,
    aiGenerateCubeQueryEnabled,
    topicsExploreProjectsPath,
    projectLevelAnalyticsProviderSettings,
    isInstanceConfiguredWithSelfManagedAnalyticsProvider,
    defaultUseInstanceConfiguration,
    overviewCountsAggregationEnabled,
  } = el.dataset;

  const analyticsDashboardPointer = buildAnalyticsDashboardPointer(analyticsDashboardPointerJSON);

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(
      {},
      {
        cacheConfig: {
          typePolicies: {
            Project: {
              fields: {
                customizableDashboards: {
                  keyArgs: ['projectPath', 'slug'],
                },
              },
            },
            CustomizableDashboards: {
              keyFields: ['slug'],
            },
          },
        },
      },
    ),
  });

  // This is a mini state to help the breadcrumb have the correct name
  const breadcrumbState = Vue.observable({
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

  const router = createRouter(routerBase, breadcrumbState);

  injectVueAppBreadcrumbs(router, AnalyticsDashboardsBreadcrumbs);

  return new Vue({
    el,
    name: 'AnalyticsDashboardsRoot',
    apolloProvider,
    router,
    provide: {
      aiGenerateCubeQueryEnabled: parseBoolean(aiGenerateCubeQueryEnabled),
      breadcrumbState,
      customDashboardsProject: analyticsDashboardPointer,
      canConfigureDashboardsProject: parseBoolean(canConfigureDashboardsProject),
      canSelectGitlabManagedProvider: parseBoolean(canSelectGitlabManagedProvider),
      managedClusterPurchased: parseBoolean(managedClusterPurchased),
      trackingKey,
      namespaceFullPath,
      namespaceId,
      isProject: parseBoolean(isProject),
      isGroup: parseBoolean(isGroup),
      namespaceName,
      collectorHost,
      chartEmptyStateIllustrationPath,
      dashboardEmptyStateIllustrationPath,
      analyticsSettingsPath,
      dashboardsPath: router.resolve('/').href,
      features: convertArrayToCamelCase(JSON.parse(features)),
      rootNamespaceName,
      rootNamespaceFullPath,
      dataSourceClickhouse: parseBoolean(dataSourceClickhouse),
      currentUserId: window.gon?.current_user_id,
      topicsExploreProjectsPath,
      projectLevelAnalyticsProviderSettings: convertObjectPropsToCamelCase(
        JSON.parse(projectLevelAnalyticsProviderSettings || '{}'),
      ),
      isInstanceConfiguredWithSelfManagedAnalyticsProvider: parseBoolean(
        isInstanceConfiguredWithSelfManagedAnalyticsProvider,
      ),
      defaultUseInstanceConfiguration: parseBoolean(defaultUseInstanceConfiguration),
      overviewCountsAggregationEnabled: parseBoolean(overviewCountsAggregationEnabled),
    },
    render(h) {
      return h(DashboardsApp);
    },
  });
};
