<script>
import { GlLink, GlAlert, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getAllCustomizableDashboardsQuery from '../graphql/queries/get_all_customizable_dashboards.query.graphql';
import DashboardListItem from './list/dashboard_list_item.vue';

const productAnalyticsOnboardingType = 'productAnalytics';
const ONBOARDING_FEATURE_COMPONENTS = {
  [productAnalyticsOnboardingType]: () =>
    import('ee/product_analytics/onboarding/components/onboarding_list_item.vue'),
};

export default {
  name: 'DashboardsList',
  components: {
    GlButton,
    GlLink,
    GlAlert,
    GlSkeletonLoader,
    DashboardListItem,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin()],
  inject: {
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    customDashboardsProject: {
      type: Object,
      default: null,
    },
    canConfigureProjectSettings: {
      type: Boolean,
    },
    namespaceFullPath: {
      type: String,
    },
    features: {
      type: Array,
      default: () => [],
    },
    analyticsSettingsPath: {
      type: String,
    },
  },
  data() {
    return {
      requiresOnboarding: Object.keys(ONBOARDING_FEATURE_COMPONENTS),
      userDashboards: [],
      alert: null,
    };
  },
  computed: {
    showVizDesignerButton() {
      return this.isProject && this.customDashboardsProject && this.productAnalyticsIsOnboarded;
    },
    showNewDashboardButton() {
      return this.isProject && this.customDashboardsProject;
    },
    dashboards() {
      return this.userDashboards;
    },
    isLoading() {
      return this.$apollo.queries.userDashboards.loading;
    },
    activeOnboardingComponents() {
      return Object.fromEntries(
        Object.entries(ONBOARDING_FEATURE_COMPONENTS)
          .filter(this.featureEnabled)
          .filter(this.featureRequiresOnboarding),
      );
    },
    showCustomDashboardSetupBanner() {
      return !this.customDashboardsProject && this.canConfigureProjectSettings;
    },
    productAnalyticsIsOnboarded() {
      return (
        this.featureEnabled([productAnalyticsOnboardingType]) &&
        !this.featureRequiresOnboarding([productAnalyticsOnboardingType])
      );
    },
  },
  mounted() {
    this.trackEvent('user_viewed_dashboard_list');
  },
  apollo: {
    userDashboards: {
      query: getAllCustomizableDashboardsQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;

        return namespaceData?.customizableDashboards?.nodes;
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();
  },
  methods: {
    featureEnabled([feature]) {
      return this.features.includes(feature);
    },
    featureRequiresOnboarding([feature]) {
      return this.requiresOnboarding.includes(feature);
    },
    routeToDashboard(dashboardId) {
      return this.$router.push(dashboardId);
    },
    onboardingComplete(feature) {
      this.requiresOnboarding = this.requiresOnboarding.filter((f) => f !== feature);

      this.$apollo.queries.userDashboards.refetch();
    },
    onError(error, captureError = true, message = '') {
      this.alert = createAlert({
        message: message || error.message,
        captureError,
        error,
      });
    },
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards'),
};
</script>

<template>
  <div>
    <header
      class="gl-display-flex gl-justify-content-space-between gl-lg-flex-direction-row gl-flex-direction-column gl-align-items-flex-start gl-my-6"
    >
      <div>
        <h2 class="gl-mt-0" data-testid="title">{{ s__('Analytics|Analytics dashboards') }}</h2>
        <p data-testid="description" class="gl-mb-0">
          {{
            isProject
              ? s__('Analytics|Dashboards are created by editing the projects dashboard files.')
              : s__('Analytics|Dashboards are created by editing the groups dashboard files.')
          }}
          <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{
            __('Learn more.')
          }}</gl-link>
        </p>
      </div>
      <div v-if="showVizDesignerButton || showNewDashboardButton">
        <gl-button
          v-if="showVizDesignerButton"
          to="visualization-designer"
          data-testid="visualization-designer-button"
        >
          {{ s__('Analytics|Visualization designer') }}
        </gl-button>
        <router-link
          v-if="showNewDashboardButton"
          to="/new"
          class="btn btn-confirm btn-md gl-button"
          data-testid="new-dashboard-button"
        >
          {{ s__('Analytics|New dashboard') }}
        </router-link>
      </div>
    </header>
    <gl-alert
      v-if="showCustomDashboardSetupBanner"
      :dismissible="false"
      :primary-button-text="s__('Analytics|Configure Dashboard Project')"
      :primary-button-link="analyticsSettingsPath"
      :title="s__('Analytics|Custom dashboards')"
      data-testid="configure-dashboard-container"
      class="gl-mt-3 gl-mb-6"
      >{{
        s__(
          'Analytics|To create your own dashboards, first configure a project to store your dashboards.',
        )
      }}</gl-alert
    >
    <ul class="content-list gl-border-t gl-border-gray-50">
      <component
        :is="setupComponent"
        v-for="(setupComponent, feature) in activeOnboardingComponents"
        :key="feature"
        @complete="onboardingComplete(feature)"
        @error="onError"
      />

      <template v-if="isLoading">
        <li v-for="n in 2" :key="n" class="gl-px-5!">
          <gl-skeleton-loader :lines="2" />
        </li>
      </template>
      <dashboard-list-item
        v-for="dashboard in dashboards"
        v-else
        :key="dashboard.slug"
        :dashboard="dashboard"
        data-event-tracking="user_visited_dashboard"
      />
    </ul>
  </div>
</template>
