<script>
import { GlTableLite, GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { toYmd } from '~/analytics/shared/utils';
import { dasherize } from '~/lib/utils/text_utility';
import { formatNumber } from '~/locale';
import { BUCKETING_INTERVAL_ALL } from '../../graphql/constants';
import VulnerabilitiesQuery from '../graphql/vulnerabilities.query.graphql';
import FlowMetricsQuery from '../graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from '../graphql/dora_metrics.query.graphql';
import AiMetricsQuery from '../graphql/ai_metrics.query.graphql';
import MetricTableCell from '../../components/metric_table_cell.vue';
import TrendIndicator from '../../components/trend_indicator.vue';
import { DASHBOARD_LOADING_FAILURE } from '../../constants';
import { mergeTableData, generateValueStreamDashboardStartDate } from '../../utils';
import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  generateTableRows,
} from '../utils';
import {
  AI_IMPACT_TABLE_METRICS,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_AI_METRICS,
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
    GlSkeletonLoader,
    MetricTableCell,
    TrendIndicator,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
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
      ];
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries();
    if (failedTableMetrics.length > 0) {
      const errors = [`${DASHBOARD_LOADING_FAILURE}: ${failedTableMetrics.join(', ')}`];
      this.$emit('set-alerts', { errors });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData();
  },
  methods: {
    rowAttributes({ metric: { identifier } }) {
      return {
        'data-testid': `ai-impact-metric-${dasherize(identifier)}`,
      };
    },

    async resolveQueries() {
      const result = await Promise.allSettled(
        this.tableQueries.map((query) => this.fetchTableMetrics(query)),
      );

      // Return an array of the failed metric IDs
      return result
        .reduce((acc, { reason = [] }) => acc.concat(reason), [])
        .map((metric) => AI_IMPACT_TABLE_METRICS[metric].label);
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
        ...extractGraphqlAiData({
          ...responseData,
          timePeriodEnd: timePeriod.end,
        }),
      };
    },
    formatNumber,
  },
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
        :request-path="namespace"
        :is-project="isProject"
      />
    </template>

    <template #cell()="{ value: { value, tooltip } }">
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <span
        v-else-if="tooltip"
        v-gl-tooltip.hover="tooltip"
        data-testid="ai-impact-table-value-cell"
        class="gl-cursor-pointer hover:gl-underline"
      >
        {{ formatNumber(value) }}
      </span>
      <span v-else data-testid="ai-impact-table-value-cell"> {{ formatNumber(value) }} </span>
    </template>

    <template #cell(change)="{ value: { value }, item: { invertTrendColor } }">
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <trend-indicator v-else-if="value !== 0" :change="value" :invert-color="invertTrendColor" />
    </template>
  </gl-table-lite>
</template>
