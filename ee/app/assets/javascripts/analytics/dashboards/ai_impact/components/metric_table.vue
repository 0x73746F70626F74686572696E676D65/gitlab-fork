<script>
import { GlTableLite, GlSkeletonLoader, GlTooltip, GlSprintf, GlLink } from '@gitlab/ui';
import { toYmd } from '~/analytics/shared/utils';
import { AI_METRICS } from '~/analytics/shared/constants';
import { dasherize } from '~/lib/utils/text_utility';
import { formatNumber, s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { InternalEvents } from '~/tracking';
import {
  AI_IMPACT_TABLE_TRACKING_PROPERTY,
  EVENT_LABEL_CLICK_METRIC_IN_DASHBOARD_TABLE,
} from 'ee/analytics/analytics_dashboards/constants';
import { BUCKETING_INTERVAL_ALL } from '../../graphql/constants';
import VulnerabilitiesQuery from '../graphql/vulnerabilities.query.graphql';
import FlowMetricsQuery from '../graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from '../graphql/dora_metrics.query.graphql';
import AiMetricsQuery from '../graphql/ai_metrics.query.graphql';
import MetricTableCell from '../../components/metric_table_cell.vue';
import TrendIndicator from '../../components/trend_indicator.vue';
import { DASHBOARD_LOADING_FAILURE, RESTRICTED_METRIC_ERROR } from '../../constants';
import { mergeTableData, generateValueStreamDashboardStartDate } from '../../utils';
import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  generateTableRows,
  getRestrictedTableMetrics,
  generateTableAlerts,
} from '../utils';
import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_AI_METRICS,
  HIDE_METRIC_DRILL_DOWN,
} from '../constants';
import {
  fetchMetricsForTimePeriods,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractQueryResponseFromNamespace,
} from '../../api';
import { extractGraphqlAiData } from '../api';

const NOW = generateValueStreamDashboardStartDate();
const DASHBOARD_TIME_PERIODS = generateDateRanges(NOW);

export default {
  name: 'MetricTable',
  components: {
    GlTableLite,
    GlTooltip,
    GlSprintf,
    GlLink,
    GlSkeletonLoader,
    MetricTableCell,
    TrendIndicator,
  },
  mixins: [glAbilitiesMixin(), InternalEvents.mixin()],
  props: {
    namespace: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      tableData: [],
    };
  },
  computed: {
    dashboardTableFields() {
      return generateTableColumns(NOW);
    },
    tableQueries() {
      return [
        { metrics: SUPPORTED_DORA_METRICS, queryFn: this.fetchDoraMetricsQuery },
        { metrics: SUPPORTED_FLOW_METRICS, queryFn: this.fetchFlowMetricsQuery },
        { metrics: SUPPORTED_AI_METRICS, queryFn: this.fetchAiMetricsQuery },
        {
          metrics: SUPPORTED_VULNERABILITY_METRICS,
          queryFn: this.fetchVulnerabilitiesMetricsQuery,
        },
      ].filter(({ metrics }) => !this.areAllMetricsRestricted(metrics));
    },
    restrictedMetrics() {
      return getRestrictedTableMetrics(this.glAbilities);
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries();

    const alerts = generateTableAlerts([[RESTRICTED_METRIC_ERROR, this.restrictedMetrics]]);
    const warnings = generateTableAlerts([[DASHBOARD_LOADING_FAILURE, failedTableMetrics]]);
    if (alerts.length > 0 || warnings.length > 0) {
      this.$emit('set-alerts', { alerts, warnings, canRetry: warnings.length > 0 });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData(this.restrictedMetrics);
  },
  methods: {
    areAllMetricsRestricted(metrics) {
      return metrics.every((metric) => this.restrictedMetrics.includes(metric));
    },

    rowAttributes({ metric: { identifier } }) {
      return {
        'data-testid': `ai-impact-metric-${dasherize(identifier)}`,
      };
    },

    requestPath(identifier) {
      return HIDE_METRIC_DRILL_DOWN.includes(identifier) ? '' : this.namespace;
    },

    handleMetricDrillDownClick(identifier) {
      if (!this.requestPath(identifier)) return;

      this.trackEvent(EVENT_LABEL_CLICK_METRIC_IN_DASHBOARD_TABLE, {
        label: identifier,
        property: AI_IMPACT_TABLE_TRACKING_PROPERTY,
      });
    },

    async resolveQueries() {
      const result = await Promise.allSettled(
        this.tableQueries.map((query) => this.fetchTableMetrics(query)),
      );

      // Return an array of the failed metric IDs
      return result.reduce((failedMetrics, { reason = [] }) => failedMetrics.concat(reason), []);
    },

    async fetchTableMetrics({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(DASHBOARD_TIME_PERIODS, queryFn);
        this.tableData = mergeTableData(this.tableData, generateTableRows(data));
      } catch (error) {
        throw metrics;
      }
    },

    async fetchDoraMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: DoraMetricsQuery,
        variables: {
          fullPath: this.namespace,
          interval: BUCKETING_INTERVAL_ALL,
          startDate,
          endDate,
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'dora',
      });
      return {
        ...timePeriod,
        ...extractGraphqlDoraData(responseData?.metrics || {}),
      };
    },

    async fetchFlowMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: FlowMetricsQuery,
        variables: {
          fullPath: this.namespace,
          startDate,
          endDate,
        },
      });

      const metrics = extractQueryResponseFromNamespace({ result, resultKey: 'flowMetrics' });
      return {
        ...timePeriod,
        ...extractGraphqlFlowData(metrics || {}),
      };
    },

    async fetchVulnerabilitiesMetricsQuery({ endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: VulnerabilitiesQuery,
        variables: {
          fullPath: this.namespace,

          // The vulnerabilities API request takes a date, so the timezone skews it outside the monthly range
          // The vulnerabilites count returns cumulative data for each day
          // we only want to use the value of the last day in the time period
          // so we override the startDate and set it to the same value as the end date
          startDate: toYmd(endDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'vulnerabilitiesCountByDay',
      });
      return {
        ...timePeriod,
        ...extractGraphqlVulnerabilitiesData(responseData?.nodes || []),
      };
    },

    async fetchAiMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: AiMetricsQuery,
        variables: {
          fullPath: this.namespace,
          startDate,
          endDate,
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'aiMetrics',
      });
      return {
        ...timePeriod,
        ...extractGraphqlAiData(responseData),
      };
    },
    formatNumber,
  },

  // Code suggestions usage only started being tracked April 4, 2024
  // https://gitlab.com/gitlab-org/gitlab/-/issues/456108
  CODE_SUGGESTIONS_START_DATE: new Date('2024-04-04'),
  CODE_SUGGESTIONS_USAGE_RATE: AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
  CODE_SUGGESTIONS_START_DATE_TOOLTIP: s__(
    'AiImpactAnalytics|The usage data may be incomplete due to backend calculations starting after upgrade to GitLab 16.11. For more information, see %{linkStart}epic 12978%{linkEnd}.',
  ),
  CODE_SUGGESTIONS_START_DATE_LINK: 'https://gitlab.com/groups/gitlab-org/-/epics/12978',
};
</script>
<template>
  <gl-table-lite
    :fields="dashboardTableFields"
    :items="tableData"
    table-class="gl-my-0"
    :tbody-tr-attr="rowAttributes"
  >
    <template #head(change)="{ field: { label, description } }">
      <div class="gl-mb-2">{{ label }}</div>
      <div class="gl-font-normal">{{ description }}</div>
    </template>

    <template #cell(metric)="{ value: { identifier } }">
      <metric-table-cell
        :identifier="identifier"
        :request-path="requestPath(identifier)"
        :is-project="isProject"
        @drill-down-clicked="handleMetricDrillDownClick(identifier)"
      />
    </template>

    <template
      #cell()="{
        value: { value, tooltip },
        field: { key, end },
        item: {
          metric: { identifier },
        },
      }"
    >
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <span v-else data-testid="ai-impact-table-value-cell">
        <span
          :ref="`${key}-${identifier}`"
          :class="{ 'gl-cursor-pointer hover:gl-underline': tooltip }"
          data-testid="formatted-metric-value"
        >
          {{ formatNumber(value) }}
        </span>

        <gl-tooltip v-if="tooltip" :target="() => $refs[`${key}-${identifier}`]">
          <gl-sprintf
            v-if="
              identifier === $options.CODE_SUGGESTIONS_USAGE_RATE &&
              end < $options.CODE_SUGGESTIONS_START_DATE
            "
            :message="$options.CODE_SUGGESTIONS_START_DATE_TOOLTIP"
          >
            <template #link="{ content }">
              <gl-link :href="$options.CODE_SUGGESTIONS_START_DATE_LINK" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
          <template v-else>{{ tooltip }}</template>
        </gl-tooltip>
      </span>
    </template>

    <template #cell(change)="{ value: { value }, item: { invertTrendColor } }">
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <trend-indicator v-else-if="value !== 0" :change="value" :invert-color="invertTrendColor" />
    </template>
  </gl-table-lite>
</template>
