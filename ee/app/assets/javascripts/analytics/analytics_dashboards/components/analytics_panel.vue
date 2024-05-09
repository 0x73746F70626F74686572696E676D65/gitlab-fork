<script>
import { GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import isString from 'lodash/isString';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { isEmptyPanelData } from 'ee/vue_shared/components/customizable_dashboard/utils';
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
    const hasValidationErrors = Boolean(validationErrors);

    return {
      errors: validationErrors || [],
      hasValidationErrors,
      canRetryError: !hasValidationErrors,
      fullPanelError: hasValidationErrors,
      data: null,
      loading: false,
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
    showEmptyState() {
      return isEmptyPanelData(this.visualization.type, this.data);
    },
    showErrorPopover() {
      return this.showErrorState && !this.dropdownOpen;
    },
    showErrorState() {
      return this.errors.length > 0;
    },
    errorMessages() {
      return this.errors.filter(isString);
    },
    errorPopoverTitle() {
      return this.hasValidationErrors
        ? s__('Analytics|Invalid visualization configuration')
        : s__('Analytics|Failed to fetch data');
    },
    errorPopoverMessage() {
      return this.hasValidationErrors
        ? s__(
            'Analytics|Something is wrong with your panel visualization configuration. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          )
        : s__(
            'Analytics|Something went wrong while connecting to your data source. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          );
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
      handler: 'fetchData',
      immediate: true,
    },
    queryOverrides: 'fetchData',
    filters: 'fetchData',
  },
  methods: {
    async fetchData() {
      if (this.hasValidationErrors) {
        return;
      }

      const { queryOverrides, filters } = this;
      const { type: dataType, query } = this.visualization.data;
      this.loading = true;
      this.clearErrors();
      const requestNumber = this.currentRequestNumber + 1;
      this.currentRequestNumber = requestNumber;

      try {
        const { fetch } = await dataSources[dataType]();
        const data = await fetch({
          title: this.title,
          projectId: this.namespaceId,
          namespace: this.namespace,
          query,
          queryOverrides,
          visualizationType: this.visualization.type,
          visualizationOptions: this.visualization.options,
          filters,
        });

        if (this.currentRequestNumber === requestNumber) {
          this.data = data;
        }
      } catch (error) {
        this.setErrors({
          errors: [error],

          // bad or malformed CubeJS query, retry won't fix
          canRetry: !this.isCubeJsBadRequest(error),
        });
      } finally {
        this.loading = false;
      }
    },
    clearErrors() {
      this.errors = [];
      this.fullPanelError = false;
    },
    setErrors({ errors, canRetry = true, fullPanelError = true }) {
      if (!canRetry) this.canRetryError = false;

      this.errors = errors;
      this.fullPanelError = fullPanelError;

      errors.forEach((error) => Sentry.captureException(error));
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
    :show-error-state="showErrorState"
    :error-popover-title="errorPopoverTitle"
    :actions="dropdownItems"
    :editing="editing"
  >
    <template #body>
      <span
        v-if="showErrorState && fullPanelError"
        class="gl-text-secondary"
        data-testid="error-body"
      >
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
        @set-errors="setErrors"
        @showTooltip="handleShowTooltip"
      />
    </template>

    <template #error-popover>
      <gl-sprintf :message="errorPopoverMessage">
        <template #link="{ content }">
          <gl-link :href="$options.PANEL_TROUBLESHOOTING_URL" class="gl-font-sm">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
      <ul v-if="errorMessages.length" data-testid="error-messages">
        <li v-for="errorMessage in errorMessages" :key="errorMessage">
          {{ errorMessage }}
        </li>
      </ul>
      <gl-button v-if="canRetryError" class="gl-display-block gl-mt-3" @click="fetchData">{{
        __('Retry')
      }}</gl-button>
    </template>
  </panels-base>
</template>
