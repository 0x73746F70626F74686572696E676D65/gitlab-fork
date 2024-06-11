<script>
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import isString from 'lodash/isString';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { isEmptyPanelData } from 'ee/vue_shared/components/customizable_dashboard/utils';
import { VARIANT_DANGER, VARIANT_INFO, VARIANT_WARNING } from '~/alert';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import { __, s__, sprintf } from '~/locale';
import PanelsBase from 'ee/vue_shared/components/customizable_dashboard/panels_base.vue';
import dataSources from '../data_sources';
import { PANEL_TROUBLESHOOTING_URL } from '../constants';

export default {
  name: 'AnalyticsDashboardPanel',
  components: {
    PanelsBase,
    GlLink,
    GlSprintf,
    GlButton,
    LineChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue'),
    ColumnChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/column_chart.vue'),
    DataTable: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/data_table.vue'),
    SingleStat: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/single_stat.vue'),
    DORAChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/dora_chart.vue'),
    UsageOverview: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/usage_overview.vue'),
    DoraPerformersScore: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/dora_performers_score.vue'
      ),
    AiImpactTable: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/ai_impact_table.vue'),
  },
  inject: [
    'namespaceId',
    'namespaceFullPath',
    'namespaceName',
    'isProject',
    'rootNamespaceName',
    'rootNamespaceFullPath',
  ],
  props: {
    visualization: {
      type: Object,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    queryOverrides: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    editing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const validationErrors = this.visualization?.errors;

    return {
      errors: [],
      warnings: [],
      alertVariant: null,
      alertTitle: '',
      alertDescription: '',
      alertDescriptionLink: '',
      validationErrors,
      canRetryError: false,
      data: null,
      loading: false,
      loadingDelayed: false,
      tooltip: '',
      dropdownItems: [
        {
          text: __('Delete'),
          action: () => this.$emit('delete'),
          icon: 'remove',
        },
      ],
      currentRequestNumber: 0,
    };
  },
  computed: {
    hasValidationErrors() {
      return Boolean(this.validationErrors);
    },
    showEmptyState() {
      return !this.showAlertState && isEmptyPanelData(this.visualization.type, this.data);
    },
    isErrorAlert() {
      return this.alertVariant === VARIANT_DANGER;
    },
    showAlertPopover() {
      return this.showAlertState && !this.dropdownOpen;
    },
    showAlertState() {
      return Boolean(this.alertMessages.length > 0 || this.alertDescription.length);
    },
    alertMessages() {
      if (this.errors.length > 0) return this.errors.filter(this.isValidAlertMessage);
      if (this.warnings.length > 0) return this.warnings.filter(this.isValidAlertMessage);
      return [];
    },
    namespace() {
      return this.namespaceFullPath;
    },
    panelTitle() {
      return sprintf(this.title, {
        namespaceName: this.namespaceName,
        namespaceType: this.isProject ? __('project') : __('group'),
        namespaceFullPath: this.namespaceFullPath,
        rootNamespaceName: this.rootNamespaceName,
        rootNamespaceFullPath: this.rootNamespaceFullPath,
      });
    },
  },
  watch: {
    visualization: {
      handler: 'onVisualizationChange',
      immediate: true,
    },
    queryOverrides: 'fetchData',
    filters: 'fetchData',
  },
  methods: {
    async importDataSourceModule(dataType) {
      const module = await dataSources[dataType]();
      return module.default;
    },
    isValidAlertMessage(message) {
      return isString(message) || (isString(message.link) && isString(message.description));
    },
    async onVisualizationChange() {
      if (this.hasValidationErrors) {
        this.setAlerts({
          errors: this.validationErrors,
          canRetry: false,
          title: s__('Analytics|Invalid visualization configuration'),
          description: s__(
            'Analytics|Something is wrong with your panel visualization configuration. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          ),
        });
        return;
      }

      this.fetchData();
    },
    async fetchData() {
      const { queryOverrides, filters } = this;
      const { type: dataType, query } = this.visualization.data;
      this.loading = true;
      this.clearAlerts();
      const requestNumber = this.currentRequestNumber + 1;
      this.currentRequestNumber = requestNumber;

      try {
        const fetch = await this.importDataSourceModule(dataType);

        const data = await fetch({
          title: this.title,
          projectId: this.namespaceId,
          namespace: this.namespace,
          query,
          queryOverrides,
          visualizationType: this.visualization.type,
          visualizationOptions: this.visualization.options,
          filters,
          onRequestDelayed: () => {
            this.loadingDelayed = true;
          },
        });

        if (this.currentRequestNumber === requestNumber) {
          this.data = data;
        }
      } catch (error) {
        const isCubeJsBadRequest = this.isCubeJsBadRequest(error);
        const additionalErrorDetails = isCubeJsBadRequest ? error.response?.message : null;

        this.setAlerts({
          errors: [error, additionalErrorDetails].filter(Boolean),
          title: s__('Analytics|Failed to fetch data'),
          description: s__(
            'Analytics|Something went wrong while connecting to your data source. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          ),

          // bad or malformed CubeJS query, retry won't fix
          canRetry: !isCubeJsBadRequest,
        });
      } finally {
        this.loading = false;
        this.loadingDelayed = false;
      }
    },
    clearAlerts() {
      this.errors = [];
      this.warnings = [];
      this.alertVariant = null;
      this.alertDescription = '';
      this.descriptionLink = '';
      this.alertTitle = '';
    },
    setAlerts({
      errors = [],
      warnings = [],
      title = '',
      description = '',
      descriptionLink = '',
      canRetry = true,
    }) {
      this.canRetryError = canRetry;

      this.errors = errors;
      this.warnings = warnings;

      if (errors.length > 0) {
        this.alertVariant = VARIANT_DANGER;
        // Only capture in sentry when we are using the error/danger variant
        // Warning / Info variants do no correlate to errors
        errors.forEach((alert) => Sentry.captureException(alert));
      } else if (warnings.length > 0) {
        this.alertVariant = VARIANT_WARNING;
      } else {
        this.alertVariant = VARIANT_INFO;
      }

      this.alertDescription = description;
      this.alertDescriptionLink = descriptionLink || this.$options.PANEL_TROUBLESHOOTING_URL;
      this.alertTitle = title;
    },
    isCubeJsBadRequest(error) {
      return Boolean(error.status === HTTP_STATUS_BAD_REQUEST && error.response?.message);
    },
    handleShowTooltip(tooltipText) {
      this.tooltip = tooltipText;
    },
  },
  PANEL_TROUBLESHOOTING_URL,
};
</script>

<template>
  <panels-base
    :title="panelTitle"
    :tooltip="tooltip"
    :loading="loading"
    :loading-delayed="loadingDelayed"
    :show-alert-state="showAlertState"
    :alert-variant="alertVariant"
    :alert-popover-title="alertTitle"
    :actions="dropdownItems"
    :editing="editing"
  >
    <template #body>
      <span v-if="isErrorAlert" class="gl-text-secondary" data-testid="alert-body">
        {{ s__('Analytics|Something went wrong.') }}
      </span>

      <span v-else-if="showEmptyState" class="gl-text-secondary">
        {{ s__('Analytics|No results match your query or filter.') }}
      </span>

      <component
        :is="visualization.type"
        v-else
        class="gl-overflow-hidden"
        :data="data"
        :options="visualization.options"
        @set-alerts="setAlerts"
        @showTooltip="handleShowTooltip"
      />
    </template>

    <template #alert-popover>
      <gl-sprintf :message="alertDescription">
        <template #link="{ content }">
          <gl-link :href="alertDescriptionLink" class="gl-font-sm">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
      <ul v-if="alertMessages.length" data-testid="alert-messages" class="gl-mb-0">
        <li v-for="(message, i) in alertMessages" :key="`alert-message-${i}`">
          <span v-if="message.link && message.description">
            <gl-sprintf :message="message.description">
              <template #link="{ content }">
                <gl-link :href="message.link" class="gl-font-sm">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
          <span v-else>{{ message }}</span>
        </li>
      </ul>
      <gl-button v-if="canRetryError" class="gl-block gl-mt-3" @click="fetchData">{{
        __('Retry')
      }}</gl-button>
    </template>
  </panels-base>
</template>
