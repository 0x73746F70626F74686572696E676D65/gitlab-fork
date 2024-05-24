<script>
import { uniq } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { toYmd } from '~/analytics/shared/utils';
import { CONTRIBUTOR_METRICS } from '~/analytics/shared/constants';
import VulnerabilitiesQuery from '../graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from '../graphql/merge_requests.query.graphql';
import FlowMetricsQuery from '../graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from '../graphql/dora_metrics.query.graphql';
import GroupContributorCountQuery from '../graphql/group_contributor_count.query.graphql';
import { BUCKETING_INTERVAL_ALL, MERGE_REQUESTS_STATE_MERGED } from '../graphql/constants';
import {
  TABLE_METRICS,
  DASHBOARD_LOADING_FAILURE,
  CHART_LOADING_FAILURE,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
} from '../constants';
import {
  fetchMetricsForTimePeriods,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractGraphqlMergeRequestsData,
  extractGraphqlContributorCountData,
  extractQueryResponseFromNamespace,
} from '../api';
import {
  generateSkeletonTableData,
  generateMetricComparisons,
  generateSparklineCharts,
  mergeTableData,
  generateDateRanges,
  generateChartTimePeriods,
  generateValueStreamDashboardStartDate,
} from '../utils';
import ComparisonTable from './comparison_table.vue';

const now = generateValueStreamDashboardStartDate();
const DASHBOARD_TIME_PERIODS = generateDateRanges(now);
const CHART_TIME_PERIODS = generateChartTimePeriods(now);

export default {
  name: 'ComparisonChart',
  components: {
    ComparisonTable,
  },
  inject: {
    dataSourceClickhouse: {
      default: false,
    },
  },
  props: {
    requestPath: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: true,
    },
    excludeMetrics: {
      type: Array,
      required: false,
      default: () => [],
    },
    filterLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      tableData: [],
    };
  },
  computed: {
    filteredQueries() {
      return [
        { metrics: SUPPORTED_DORA_METRICS, queryFn: this.fetchDoraMetricsQuery },
        { metrics: SUPPORTED_FLOW_METRICS, queryFn: this.fetchFlowMetricsQuery },
        { metrics: SUPPORTED_MERGE_REQUEST_METRICS, queryFn: this.fetchMergeRequestsMetricsQuery },
        {
          metrics: SUPPORTED_VULNERABILITY_METRICS,
          queryFn: this.fetchVulnerabilitiesMetricsQuery,
        },
        {
          metrics: SUPPORTED_CONTRIBUTOR_METRICS,
          queryFn: this.fetchContributorsCountQuery,
        },
      ].filter(({ metrics }) => this.areAnyMetricsIncluded(metrics));
    },
    shouldRenderContributorsCountMetric() {
      // Contributors count metric is not supported at the project level or when the Clickhouse data store is disabled
      return !this.isProject && this.dataSourceClickhouse;
    },
    skippedMetrics() {
      return uniq([
        ...(!this.shouldRenderContributorsCountMetric ? [CONTRIBUTOR_METRICS.COUNT] : []),
        ...this.excludeMetrics,
      ]);
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries(this.fetchTableMetrics);
    const failedChartMetrics = await this.resolveQueries(this.fetchSparklineCharts);

    if ([...failedTableMetrics, ...failedChartMetrics].length > 0) {
      const errors = [];
      if (failedTableMetrics) {
        errors.push(`${DASHBOARD_LOADING_FAILURE}: ${failedTableMetrics.join(', ')}`);
      }
      if (failedChartMetrics) {
        errors.push(`${CHART_LOADING_FAILURE}: ${failedChartMetrics.join(', ')}`);
      }

      this.$emit('set-alerts', { errors });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData(this.skippedMetrics);
  },
  methods: {
    areAnyMetricsIncluded(identifiers) {
      return !identifiers.every((identifier) => this.skippedMetrics.includes(identifier));
    },

    async resolveQueries(handler) {
      const result = await Promise.allSettled(this.filteredQueries.map((query) => handler(query)));

      // Return an array of the failed metric IDs
      return result
        .reduce((acc, { reason = [] }) => acc.concat(reason), [])
        .map((metric) => TABLE_METRICS[metric].label);
    },

    async fetchTableMetrics({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(DASHBOARD_TIME_PERIODS, queryFn);
        this.tableData = mergeTableData(this.tableData, generateMetricComparisons(data));
      } catch (error) {
        Sentry.captureException(error);
        throw metrics;
      }
    },

    async fetchSparklineCharts({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(CHART_TIME_PERIODS, queryFn);
        this.tableData = mergeTableData(this.tableData, generateSparklineCharts(data));
      } catch (error) {
        Sentry.captureException(error);
        throw metrics;
      }
    },

    async fetchDoraMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: DoraMetricsQuery,
        variables: {
          fullPath: this.requestPath,
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
          fullPath: this.requestPath,
          labelNames: this.filterLabels,
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

    async fetchMergeRequestsMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: MergeRequestsQuery,
        variables: {
          fullPath: this.requestPath,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
          state: MERGE_REQUESTS_STATE_MERGED,
          labelNames: this.filterLabels.length > 0 ? this.filterLabels : null,
        },
      });

      const metrics = extractQueryResponseFromNamespace({
        result,
        resultKey: 'mergeRequests',
      });
      return {
        ...timePeriod,
        ...extractGraphqlMergeRequestsData(metrics || {}),
      };
    },

    async fetchVulnerabilitiesMetricsQuery({ endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: VulnerabilitiesQuery,
        variables: {
          fullPath: this.requestPath,

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
    async fetchContributorsCountQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: GroupContributorCountQuery,
        variables: {
          fullPath: this.requestPath,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'contributors',
      });

      return {
        ...timePeriod,
        ...extractGraphqlContributorCountData(responseData || {}),
      };
    },
  },
  now,
};
</script>
<template>
  <div data-testid="dora-comparison-chart">
    <comparison-table
      :table-data="tableData"
      :request-path="requestPath"
      :is-project="isProject"
      :now="$options.now"
      :filter-labels="filterLabels"
    />
  </div>
</template>
