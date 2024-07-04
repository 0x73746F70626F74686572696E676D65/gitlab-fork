<script>
import { GlEmptyState, GlSkeletonLoader, GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import CustomizableDashboard from 'ee/vue_shared/components/customizable_dashboard/customizable_dashboard.vue';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import ValueStreamFeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';
import {
  buildDefaultDashboardFilters,
  getDashboardConfig,
  updateApolloCache,
  getUniquePanelId,
} from 'ee/vue_shared/components/customizable_dashboard/utils';
import { saveCustomDashboard } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import {
  BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS,
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
  AI_IMPACT_DASHBOARD,
} from 'ee/analytics/dashboards/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  FILE_ALREADY_EXISTS_SERVER_RESPONSE,
  NEW_DASHBOARD,
  EVENT_LABEL_CREATED_DASHBOARD,
  EVENT_LABEL_EDITED_DASHBOARD,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_VIEWED_DASHBOARD,
  DEFAULT_DASHBOARD_LOADING_ERROR,
  DASHBOARD_REFRESH_MESSAGE,
} from '../constants';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import getAvailableVisualizations from '../graphql/queries/get_all_customizable_visualizations.query.graphql';
import AnalyticsDashboardPanel from './analytics_dashboard_panel.vue';

// Avoid adding new values here, as this will eventually be migrated to the dashboard YAML config.
// See: https://gitlab.com/gitlab-org/gitlab/-/issues/452228
const HIDE_DASHBOARD_FILTERS = [
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
  AI_IMPACT_DASHBOARD,
];

export default {
  name: 'AnalyticsDashboard',
  components: {
    AnalyticsDashboardPanel,
    CustomizableDashboard,
    ProductAnalyticsFeedbackBanner,
    ValueStreamFeedbackBanner,
    GlEmptyState,
    GlSkeletonLoader,
    GlAlert,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  inject: {
    customDashboardsProject: {
      type: Object,
      default: null,
    },
    namespaceFullPath: {
      type: String,
    },
    namespaceId: {
      type: String,
    },
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    dashboardEmptyStateIllustrationPath: {
      type: String,
    },
    breadcrumbState: {
      type: Object,
    },
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  async beforeRouteLeave(to, from, next) {
    const confirmed = await this.$refs.dashboard.confirmDiscardIfChanged();

    if (!confirmed) return;

    next();
  },
  props: {
    isNewDashboard: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      initialDashboard: null,
      showEmptyState: false,
      availableVisualizations: {
        loading: true,
        hasError: false,
        visualizations: [],
      },
      defaultFilters: buildDefaultDashboardFilters(window.location.search),
      isSaving: false,
      titleValidationError: null,
      backUrl: this.$router.resolve('/').href,
      changesSaved: false,
      alert: null,
      hasDashboardLoadError: false,
      savedPanels: null,
    };
  },
  computed: {
    currentDashboard() {
      return this.initialDashboard;
    },
    showValueStreamFeedbackBanner() {
      return [BUILT_IN_VALUE_STREAM_DASHBOARD, CUSTOM_VALUE_STREAM_DASHBOARD].includes(
        this.currentDashboard?.slug,
      );
    },
    showProductAnalyticsFeedbackBanner() {
      return (
        !this.currentDashboard?.userDefined &&
        BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS.includes(this.currentDashboard?.slug)
      );
    },
    showDashboardFilters() {
      return !HIDE_DASHBOARD_FILTERS.includes(this.currentDashboard?.slug);
    },
    invalidDashboardErrors() {
      return this.currentDashboard?.errors ?? [];
    },
    hasDashboardError() {
      return this.hasDashboardLoadError || this.invalidDashboardErrors.length > 0;
    },
  },
  watch: {
    initialDashboard({ title: label, userDefined } = {}) {
      this.trackEvent(EVENT_LABEL_VIEWED_DASHBOARD, {
        ...(!this.isNewDashboard && { label }),
      });

      if (userDefined) {
        this.trackEvent(EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD, {
          ...(!this.isNewDashboard && { label }),
        });
      } else {
        this.trackEvent(EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD, {
          label,
        });
      }
    },
  },
  async created() {
    if (this.isNewDashboard) {
      this.initialDashboard = this.createNewDashboard();
    }
  },
  beforeDestroy() {
    this.alert?.dismiss();

    // Clear the breadcrumb name when we leave this component so it doesn't
    // flash the wrong name when a user views a different dashboard
    this.breadcrumbState.updateName('');
  },
  apollo: {
    initialDashboard: {
      query: getCustomizableDashboardQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          slug: this.$route?.params.slug,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      skip() {
        return this.isNewDashboard;
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;
        const [dashboard] = namespaceData?.customizableDashboards?.nodes || [];

        if (!dashboard) {
          this.showEmptyState = true;
          return null;
        }

        return {
          ...dashboard,
          panels: this.getDashboardPanels(dashboard),
        };
      },
      result() {
        this.breadcrumbState.updateName(this.initialDashboard?.title || '');
      },
      error(error) {
        const message = [
          error.message || DEFAULT_DASHBOARD_LOADING_ERROR,
          DASHBOARD_REFRESH_MESSAGE,
        ].join('. ');

        this.showError({
          error,
          capture: true,
          title: s__('Analytics|Failed to load dashboard'),
          message,
          messageLinks: {
            link: this.$options.troubleshootingUrl,
          },
        });
        this.hasDashboardLoadError = true;
      },
    },
    availableVisualizations: {
      query: getAvailableVisualizations,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      skip() {
        return !this.initialDashboard || !this.initialDashboard?.userDefined;
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;
        const visualizations = namespaceData?.customizableDashboardVisualizations?.nodes || [];
        return {
          loading: false,
          hasError: false,
          visualizations,
        };
      },
      error(error) {
        this.availableVisualizations = {
          loading: false,
          hasError: true,
          visualizations: [],
        };

        Sentry.captureException(error);
      },
    },
  },
  methods: {
    createNewDashboard() {
      return NEW_DASHBOARD();
    },
    getDashboardPanels(dashboard) {
      // Panel ids need to remain consistent and they are unique to the
      // frontend. Thus they don't get saved with GraphQL and we need to
      // reference the saved panels array to persist the ids.
      if (this.savedPanels) return this.savedPanels;

      const panels = dashboard.panels?.nodes || [];

      return panels.map(({ id, ...panel }) => ({
        ...panel,
        id: getUniquePanelId(),
      }));
    },
    async saveDashboard(dashboardSlug, dashboard) {
      this.validateDashboardTitle(dashboard.title, true);
      if (this.titleValidationError) {
        return;
      }

      try {
        this.changesSaved = false;
        this.isSaving = true;
        const saveResult = await saveCustomDashboard({
          dashboardSlug,
          dashboardConfig: getDashboardConfig(dashboard),
          projectInfo: this.customDashboardsProject,
          isNewFile: this.isNewDashboard,
        });

        if (saveResult?.status === HTTP_STATUS_CREATED) {
          this.alert?.dismiss();

          this.$toast.show(s__('Analytics|Dashboard was saved successfully'));

          if (this.isNewDashboard) {
            this.trackEvent(EVENT_LABEL_CREATED_DASHBOARD, {
              label: dashboard.title,
            });
          } else {
            this.trackEvent(EVENT_LABEL_EDITED_DASHBOARD, {
              label: dashboard.title,
            });
          }

          const apolloClient = this.$apollo.getClient();
          updateApolloCache({
            apolloClient,
            slug: dashboardSlug,
            dashboard,
            fullPath: this.namespaceFullPath,
            isProject: this.isProject,
            isGroup: this.isGroup,
          });

          this.savedPanels = dashboard.panels;

          if (this.isNewDashboard) {
            // We redirect now to the new route
            this.$router.push({
              name: 'dashboard-detail',
              params: { slug: dashboardSlug },
            });
          }

          this.changesSaved = true;
        } else {
          throw new Error(`Bad save dashboard response. Status:${saveResult?.status}`);
        }
      } catch (error) {
        const { message = '' } = error?.response?.data || {};

        if (message === FILE_ALREADY_EXISTS_SERVER_RESPONSE) {
          this.titleValidationError = s__('Analytics|A dashboard with that name already exists.');
        } else if (error.response?.status === HTTP_STATUS_BAD_REQUEST) {
          // We can assume bad request errors are a result of user error.
          // We don't need to capture these errors and can render the message to the user.
          this.showError({ error, capture: false, message: error.response?.data?.message });
        } else {
          this.showError({ error, capture: true });
        }
      } finally {
        this.isSaving = false;
      }
    },
    showError({ error, capture, message, messageLinks, title = '' }) {
      this.alert = createAlert({
        title,
        message: message || s__('Analytics|Error while saving dashboard'),
        messageLinks,
        error,
        captureError: capture,
      });
    },
    validateDashboardTitle(newTitle, submitting) {
      if (this.titleValidationError !== null || submitting) {
        this.titleValidationError = newTitle?.length > 0 ? '' : __('This field is required.');
      }
    },
    panelTestId({ visualization: { slug = '' } }) {
      return `panel-${slug.replaceAll('_', '-')}`;
    },
  },
  troubleshootingUrl: helpPagePath('user/analytics/analytics_dashboards', {
    anchor: '#troubleshooting',
  }),
};
</script>

<template>
  <div>
    <template v-if="currentDashboard">
      <gl-alert
        v-if="invalidDashboardErrors.length > 0"
        data-testid="analytics-dashboard-invalid-config-alert"
        class="gl-mt-4"
        :title="s__('Analytics|Invalid dashboard configuration')"
        :primary-button-text="__('Learn more')"
        :primary-button-link="$options.troubleshootingUrl"
        :dismissible="false"
        variant="danger"
      >
        <ul class="gl-m-0">
          <li v-for="errorMessage in invalidDashboardErrors" :key="errorMessage">
            {{ errorMessage }}
          </li>
        </ul>
      </gl-alert>
      <value-stream-feedback-banner v-if="showValueStreamFeedbackBanner" />
      <product-analytics-feedback-banner v-if="showProductAnalyticsFeedbackBanner" />
      <customizable-dashboard
        ref="dashboard"
        :initial-dashboard="currentDashboard"
        :available-visualizations="availableVisualizations"
        :default-filters="defaultFilters"
        :is-saving="isSaving"
        :date-range-limit="0"
        :sync-url-filters="!isNewDashboard"
        :is-new-dashboard="isNewDashboard"
        :show-date-range-filter="showDashboardFilters"
        :show-anon-users-filter="showDashboardFilters"
        :changes-saved="changesSaved"
        :title-validation-error="titleValidationError"
        :overview-counts-aggregation-enabled="overviewCountsAggregationEnabled"
        @save="saveDashboard"
        @title-input="validateDashboardTitle"
      >
        <template #panel="{ panel, filters, editing, deletePanel }">
          <analytics-dashboard-panel
            :title="panel.title"
            :visualization="panel.visualization"
            :query-overrides="panel.queryOverrides || undefined"
            :filters="filters"
            :editing="editing"
            :data-testid="panelTestId(panel)"
            @delete="deletePanel"
          />
        </template>
      </customizable-dashboard>
    </template>
    <gl-empty-state
      v-else-if="showEmptyState"
      :svg-path="dashboardEmptyStateIllustrationPath"
      :svg-height="null"
      :title="s__('Analytics|Dashboard not found')"
      :description="s__('Analytics|No dashboard matches the specified URL path.')"
      :primary-button-text="s__('Analytics|View available dashboards')"
      :primary-button-link="backUrl"
    />
    <div v-else-if="!hasDashboardError" class="gl-mt-7">
      <gl-skeleton-loader />
    </div>
  </div>
</template>
