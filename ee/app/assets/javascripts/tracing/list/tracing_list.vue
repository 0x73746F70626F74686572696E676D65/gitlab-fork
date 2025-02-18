<script>
import { GlLoadingIcon, GlInfiniteScroll, GlSprintf, GlLink } from '@gitlab/ui';
import { throttle } from 'lodash';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, joinPaths, queryToObject, DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';
import { InternalEvents } from '~/tracking';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { contentTop, isMetaClick } from '~/lib/utils/common_utils';
import { DEFAULT_SORTING_OPTION } from '~/observability/constants';
import axios from '~/lib/utils/axios_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ObservabilityNoDataEmptyState from '~/observability/components/observability_no_data_empty_state.vue';
import { VIEW_TRACING_PAGE } from '../events';
import { queryToFilterObj, filterObjToQuery } from './filter_bar/filters';
import TracingTableList from './tracing_table.vue';
import FilteredSearch from './filter_bar/tracing_filtered_search.vue';
import TracingAnalytics from './tracing_analytics.vue';

const PAGE_SIZE = 50;
const TRACING_LIST_VERTICAL_PADDING = 150; // Accounts for the search bar height + the legend height + some more v padding

export default {
  components: {
    PageHeading,
    GlLoadingIcon,
    TracingTableList,
    FilteredSearch,
    UrlSync,
    GlSprintf,
    GlInfiniteScroll,
    TracingAnalytics,
    GlLink,
    ObservabilityNoDataEmptyState,
  },
  mixins: [InternalEvents.mixin()],
  i18n: {
    infiniteScrollLegend: s__(`Tracing|Showing %{count} traces`),
    pageTitle: s__(`Tracing|Tracing`),
    description: s__(
      `Tracing|Inspect application requests across services. Send trace data to this project using OpenTelemetry. %{docsLink}`,
    ),
    docsLinkText: s__(`Tracing|Learn more.`),
  },
  docsLink: `${DOCS_URL_IN_EE_DIR}/operations/tracing`,
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    const query = window.location.search;
    const { sortBy } = queryToObject(query, { gatherArrays: true });

    return {
      loadingTraces: false,
      loadingAnalytics: false,
      fetchTracesAbortController: null,
      fetchAnalyticsAbortController: null,
      traces: [],
      analytics: [],
      filters: queryToFilterObj(query),
      nextPageToken: null,
      sortBy: sortBy || DEFAULT_SORTING_OPTION,
      listHeight: 0,
      analyticsChartsHeight: 0,
    };
  },
  computed: {
    query() {
      const filterQuery = filterObjToQuery(this.filters);
      return {
        ...filterQuery,
        sortBy: this.sortBy,
      };
    },
  },
  created() {
    this.fetchTraces();
    this.fetchAnalytics();
  },
  mounted() {
    this.trackEvent(VIEW_TRACING_PAGE);
    this.resize();
    this.resizeThrottled = throttle(() => {
      this.resize();
    }, 400);
    window.addEventListener('resize', this.resizeThrottled);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.resizeThrottled, false);
  },
  methods: {
    async fetchTraces() {
      if (this.fetchTracesAbortController) {
        this.fetchTracesAbortController.abort();
        this.fetchTracesAbortController = null;
      }
      try {
        this.loadingTraces = true;
        this.fetchTracesAbortController = new AbortController();
        const { traces, next_page_token: nextPageToken } =
          await this.observabilityClient.fetchTraces({
            filters: this.filters,
            pageToken: this.nextPageToken,
            pageSize: PAGE_SIZE,
            sortBy: this.sortBy,
            abortController: this.fetchTracesAbortController,
          });
        this.traces = [...this.traces, ...traces];
        if (nextPageToken) {
          this.nextPageToken = nextPageToken;
        }
        this.loadingTraces = false;
        this.fetchTracesAbortController = null;
      } catch (e) {
        if (!axios.isCancel(e)) {
          this.loadingTraces = false;
          createAlert({
            message: s__('Tracing|Failed to load traces.'),
          });
        }
      }
    },
    async fetchAnalytics() {
      if (this.fetchAnalyticsAbortController) {
        this.fetchAnalyticsAbortController.abort();
        this.fetchAnalyticsAbortController = null;
      }
      try {
        this.loadingAnalytics = true;
        this.fetchAnalyticsAbortController = new AbortController();
        this.analytics = await this.observabilityClient.fetchTracesAnalytics({
          filters: this.filters,
          abortController: this.fetchAnalyticsAbortController,
        });
        this.loadingAnalytics = false;
      } catch (e) {
        if (!axios.isCancel(e)) {
          this.loadingAnalytics = false;
          createAlert({
            message: s__('Tracing|Failed to load tracing analytics.'),
          });
        }
      }
    },
    onTraceClicked({ traceId, clickEvent = {} }) {
      const external = isMetaClick(clickEvent);
      visitUrl(joinPaths(window.location.pathname, traceId), external);
    },
    handleFilters(filters) {
      this.filters = filters;
      this.nextPageToken = null;
      this.traces = [];
      this.analytics = [];
      this.fetchTraces();
      this.fetchAnalytics();
    },
    onSort(sortBy) {
      this.sortBy = sortBy;
      this.nextPageToken = null;
      this.traces = [];
      this.fetchTraces();
    },
    bottomReached() {
      this.fetchTraces();
    },
    resize() {
      const containerHeight = window.innerHeight - contentTop();
      this.analyticsChartsHeight = Math.max(100, (containerHeight * 20) / 100);
      this.listHeight =
        containerHeight - this.analyticsChartsHeight - TRACING_LIST_VERTICAL_PADDING;
    },
  },
};
</script>

<template>
  <div class="gl-px-4">
    <url-sync :query="query" />

    <header>
      <page-heading :heading="$options.i18n.pageTitle">
        <template #description>
          <gl-sprintf :message="$options.i18n.description">
            <template #docsLink>
              <gl-link target="_blank" :href="$options.docsLink">
                <span>{{ $options.i18n.docsLinkText }}</span>
              </gl-link>
            </template>
          </gl-sprintf>
        </template>
      </page-heading>
    </header>

    <filtered-search
      :attributes-filters="filters.attributes"
      :date-range-filter="filters.dateRange"
      :observability-client="observabilityClient"
      :initial-sort="sortBy"
      @filter="handleFilters"
      @sort="onSort"
    />

    <tracing-analytics
      :analytics="analytics"
      :loading="loadingAnalytics"
      :chart-height="analyticsChartsHeight"
    />

    <div v-if="loadingTraces && traces.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <gl-infinite-scroll
      v-else
      :max-list-height="listHeight"
      :fetched-items="traces.length"
      @bottomReached="bottomReached"
    >
      <template #items>
        <observability-no-data-empty-state v-if="!traces.length" />
        <tracing-table-list v-else :traces="traces" @trace-clicked="onTraceClicked" />
      </template>

      <template #default>
        <gl-loading-icon v-if="loadingTraces" size="md" />
        <span v-else data-testid="tracing-infinite-scrolling-legend">
          <gl-sprintf v-if="traces.length" :message="$options.i18n.infiniteScrollLegend">
            <template #count>{{ traces.length }}</template>
          </gl-sprintf>
        </span>
      </template>
    </gl-infinite-scroll>
  </div>
</template>
