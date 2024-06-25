<script>
import { GlLoadingIcon, GlEmptyState, GlSprintf } from '@gitlab/ui';
import EMPTY_CHART_SVG from '@gitlab/svgs/dist/illustrations/chart-empty-state.svg?url';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, isSafeURL } from '~/lib/utils/url_utility';
import {
  prepareTokens,
  processFilters as processFilteredSearchFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import axios from '~/lib/utils/axios_utils';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { TIME_RANGE_OPTIONS } from '~/observability/constants';
import { InternalEvents } from '~/tracking';
import { ingestedAtTimeAgo } from '../utils';
import { METRIC_TYPE } from '../constants';
import { VIEW_METRICS_DETAILS_PAGE } from '../events';
import MetricsLineChart from './metrics_line_chart.vue';
import FilteredSearch from './filter_bar/metrics_filtered_search.vue';
import { filterObjToQuery, queryToFilterObj } from './filters';
import MetricsHeatMap from './metrics_heatmap.vue';

const VISUAL_HEATMAP = 'heatmap';

export default {
  i18n: {
    error: s__(
      'ObservabilityMetrics|Error: Failed to load metrics details. Try reloading the page.',
    ),
    metricType: s__('ObservabilityMetrics|Type'),
    lastIngested: s__('ObservabilityMetrics|Last ingested'),
    cancelledWarning: s__('ObservabilityMetrics|Metrics search has been cancelled.'),
  },
  components: {
    GlSprintf,
    GlLoadingIcon,
    MetricsLineChart,
    GlEmptyState,
    FilteredSearch,
    UrlSync,
    MetricsHeatMap,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
    metricId: {
      required: true,
      type: String,
    },
    metricType: {
      required: true,
      type: String,
    },
    metricsIndexUrl: {
      required: true,
      type: String,
      validator: (val) => isSafeURL(val),
    },
  },
  data() {
    return {
      metricData: null,
      searchMetadata: null,
      filters: queryToFilterObj(window.location.search),
      apiAbortController: null,
      loading: false,
      queryCancelled: false,
    };
  },
  computed: {
    header() {
      return {
        title: this.metricId,
        type: this.metricType,
        lastIngested: ingestedAtTimeAgo(this.searchMetadata?.last_ingested_at),
        description: this.searchMetadata?.description,
      };
    },
    attributeFiltersValue() {
      // only attributes are used by the filtered_search component, so only those needs processing
      return prepareTokens(this.filters.attributes);
    },
    query() {
      return filterObjToQuery(this.filters);
    },
    noDataTimeText() {
      const selectedValue = this.filters?.dateRange?.value;
      if (selectedValue) {
        const option = TIME_RANGE_OPTIONS.find((timeOption) => timeOption.value === selectedValue);
        if (option) {
          return `(${option.title.toLowerCase()})`;
        }
      }
      return '';
    },
    shouldShowLoadingIcon() {
      // only show the spinner on the first load or when there is no metric
      return this.loading && this.noMetric;
    },
    isHistogram() {
      return (
        this.metricType.toLowerCase() === METRIC_TYPE.ExponentialHistogram ||
        this.metricType.toLowerCase() === METRIC_TYPE.Histogram
      );
    },
    noMetric() {
      return !this.metricData || !this.metricData.length;
    },
  },
  created() {
    this.validateAndFetch();
  },
  mounted() {
    this.trackEvent(VIEW_METRICS_DETAILS_PAGE);
  },
  methods: {
    async validateAndFetch() {
      if (!this.metricId || !this.metricType) {
        createAlert({
          message: this.$options.i18n.error,
        });
        return;
      }
      this.loading = true;
      try {
        const enabled = await this.observabilityClient.isObservabilityEnabled();
        if (enabled) {
          await Promise.all([this.fetchMetricSearchMetadata(), await this.fetchMetricData()]);
        } else {
          this.goToMetricsIndex();
        }
      } catch (e) {
        createAlert({
          message: this.$options.i18n.error,
        });
      } finally {
        this.loading = false;
      }
    },
    async fetchMetricSearchMetadata() {
      try {
        this.searchMetadata = await this.observabilityClient.fetchMetricSearchMetadata(
          this.metricId,
          this.metricType,
        );
      } catch (e) {
        createAlert({
          message: this.$options.i18n.error,
        });
      }
    },
    async fetchMetricData() {
      this.queryCancelled = false;
      this.loading = true;
      try {
        this.apiAbortController = new AbortController();
        const metricData = await this.observabilityClient.fetchMetric(
          this.metricId,
          this.metricType,
          {
            filters: this.filters,
            abortController: this.apiAbortController,
            ...(this.isHistogram && { visual: VISUAL_HEATMAP }),
          },
        );
        // gl-chart is merging data by default. As I workaround we can
        // set the data to [] first, as explained in https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2577
        this.metricData = [];
        this.$nextTick(() => {
          this.metricData = metricData;
        });
      } catch (e) {
        if (axios.isCancel(e)) {
          this.cancel();
        } else {
          createAlert({
            message: this.$options.i18n.error,
          });
        }
      } finally {
        this.apiAbortController = null;
        this.loading = false;
      }
    },
    goToMetricsIndex() {
      visitUrl(this.metricsIndexUrl);
    },
    onSubmit({ attributes, dateRange, groupBy }) {
      this.filters = {
        // only attributes are used by the filtered_search component, so only those needs processing
        attributes: processFilteredSearchFilters(attributes),
        dateRange,
        groupBy,
      };
      this.fetchMetricData();
    },
    onCancel() {
      this.apiAbortController?.abort();
    },
    cancel() {
      this.$toast.show(this.$options.i18n.cancelledWarning, {
        variant: 'danger',
      });
      this.queryCancelled = true;
    },
    getChartComponent() {
      return this.isHistogram ? MetricsHeatMap : MetricsLineChart;
    },
  },
  EMPTY_CHART_SVG,
};
</script>

<template>
  <div v-if="shouldShowLoadingIcon" class="gl-py-5">
    <gl-loading-icon size="lg" />
  </div>

  <div v-else data-testid="metric-details" class="gl-m-7">
    <url-sync :query="query" />

    <div data-testid="metric-header">
      <h1 class="gl-font-size-h1 gl-my-0" data-testid="metric-title">{{ header.title }}</h1>
      <p class="gl-my-0" data-testid="metric-type">
        <strong>{{ $options.i18n.metricType }}:&nbsp;</strong>{{ header.type }}
      </p>
      <p class="gl-my-0" data-testid="metric-last-ingested">
        <strong>{{ $options.i18n.lastIngested }}:&nbsp;</strong>{{ header.lastIngested }}
      </p>
      <p class="gl-my-0" data-testid="metric-description">{{ header.description }}</p>
    </div>

    <div class="gl-my-6">
      <filtered-search
        v-if="searchMetadata"
        :loading="loading"
        :search-metadata="searchMetadata"
        :attribute-filters="attributeFiltersValue"
        :date-range-filter="filters.dateRange"
        :group-by-filter="filters.groupBy"
        @submit="onSubmit"
        @cancel="onCancel"
      />

      <component
        :is="getChartComponent()"
        v-if="metricData && metricData.length"
        :metric-data="metricData"
        :loading="loading"
        :cancelled="queryCancelled"
        data-testid="metric-chart"
      />
      <gl-empty-state v-else :svg-path="$options.EMPTY_CHART_SVG">
        <template #title>
          <p class="gl-font-lg gl-my-0">
            <gl-sprintf
              :message="
                s__('ObservabilityMetrics|No data found for the selected time range %{time}')
              "
            >
              <template #time>
                {{ noDataTimeText }}
              </template>
            </gl-sprintf>
          </p>

          <p class="gl-font-md gl-my-1">
            <strong>{{ $options.i18n.lastIngested }}:&nbsp;</strong>{{ header.lastIngested }}
          </p>
        </template>
      </gl-empty-state>
    </div>
  </div>
</template>
