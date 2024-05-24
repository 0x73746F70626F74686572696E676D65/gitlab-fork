<script>
import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { throttle } from 'lodash';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { contentTop } from '~/lib/utils/common_utils';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { queryToObject } from '~/lib/utils/url_utility';
import LogsTable from './logs_table.vue';
import LogsDrawer from './logs_drawer.vue';
import LogsFilteredSearch from './filter_bar/logs_filtered_search.vue';
import { queryToFilterObj, filterObjToQuery, selectedLogQueryObject } from './filter_bar/filters';
import LogsVolume from './logs_volume.vue';

const PAGE_SIZE = 100;

const OPEN_DRAWER_QUERY_PARAM = 'drawerOpen';

export default {
  components: {
    GlLoadingIcon,
    LogsTable,
    LogsDrawer,
    GlInfiniteScroll,
    GlSprintf,
    LogsFilteredSearch,
    UrlSync,
    LogsVolume,
  },
  i18n: {
    infiniteScrollLegend: s__(`ObservabilityLogs|Showing %{count} logs`),
  },
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    const { [OPEN_DRAWER_QUERY_PARAM]: shouldOpenDrawer } = queryToObject(window.location.search);
    return {
      loadingLogs: false,
      loadingMetadata: false,
      logs: [],
      metadata: {},
      filters: queryToFilterObj(window.location.search),
      shouldOpenDrawer: shouldOpenDrawer === 'true',
      selectedLog: null,
      nextPageToken: null,
      logsVolumeChartHeight: 0,
      listHeight: 0,
    };
  },
  computed: {
    query() {
      if (this.selectedLog) {
        return {
          ...selectedLogQueryObject(this.selectedLog),
          [OPEN_DRAWER_QUERY_PARAM]: true,
        };
      }
      return { ...filterObjToQuery(this.filters), [OPEN_DRAWER_QUERY_PARAM]: undefined };
    },
    logsSearchMetadata() {
      return this.metadata.summary;
    },
    logsVolumeCount() {
      return this.metadata.severity_numbers_counts ?? [];
    },
  },
  created() {
    this.fetchLogs();
    this.fetchMetadata();
  },
  mounted() {
    this.$nextTick(() => this.resize());
    this.resizeThrottled = throttle(() => {
      this.resize();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    window.addEventListener('resize', this.resizeThrottled);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.resizeThrottled);
  },
  methods: {
    async fetchLogs() {
      this.loadingLogs = true;
      try {
        const { logs, nextPageToken } = await this.observabilityClient.fetchLogs({
          pageToken: this.nextPageToken,
          pageSize: PAGE_SIZE,
          filters: this.filters,
        });
        this.logs = [...this.logs, ...logs];
        if (nextPageToken) {
          this.nextPageToken = nextPageToken;
        }
        if (this.shouldOpenDrawer) {
          this.shouldOpenDrawer = false;
          const [selectedFingerprint] = this.filters.attributes?.fingerprint || [];
          if (selectedFingerprint?.value) {
            this.selectLog(selectedFingerprint?.value);
          }
        }
      } catch {
        createAlert({
          message: s__('ObservabilityLogs|Failed to load logs.'),
        });
      } finally {
        this.loadingLogs = false;
      }
    },
    async fetchMetadata() {
      this.loadingMetadata = true;
      try {
        this.metadata = await this.observabilityClient.fetchLogsSearchMetadata({
          filters: this.filters,
        });
      } catch {
        createAlert({
          message: s__('ObservabilityLogs|Failed to load metadata.'),
        });
      } finally {
        this.loadingMetadata = false;
      }
    },
    onToggleDrawer({ fingerprint }) {
      if (this.selectedLog?.fingerprint === fingerprint) {
        this.closeDrawer();
      } else {
        this.selectLog(fingerprint);
      }
    },
    selectLog(fingerprint) {
      const log = this.logs.find((s) => s.fingerprint === fingerprint);
      this.selectedLog = log;
    },
    closeDrawer() {
      this.selectedLog = null;
    },
    bottomReached() {
      this.fetchLogs();
    },
    onFilter({ dateRange, attributes }) {
      this.nextPageToken = null;
      this.logs = [];
      this.metadata = {};
      this.filters = {
        dateRange,
        attributes,
      };
      this.closeDrawer();
      this.fetchLogs();
      this.fetchMetadata();
    },
    resize() {
      // Note: this JS measurements are just temporary. We will soon replace InfiniteScrolling with Pagination
      // and review the page layout https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2824
      const searchBarHeight = this.$refs.filteredSearch.$el.clientHeight;
      const containerHeight = window.innerHeight - contentTop() - searchBarHeight;
      // volume chart should be 20% of the container
      this.logsVolumeChartHeight = Math.max(100, (containerHeight * 20) / 100);
      // some hardcoded vertical padding needed to account for the infinitescrolling legend
      const LIST_V_PADDING = 90;
      this.listHeight = containerHeight - this.logsVolumeChartHeight - LIST_V_PADDING;
    },
  },
};
</script>

<template>
  <div class="gl-px-4">
    <url-sync :query="query" />

    <logs-filtered-search
      ref="filteredSearch"
      :date-range-filter="filters.dateRange"
      :attributes-filters="filters.attributes"
      :search-metadata="logsSearchMetadata"
      @filter="onFilter"
    />

    <logs-volume
      :logs-count="logsVolumeCount"
      :loading="loadingMetadata"
      :height="logsVolumeChartHeight"
    />

    <div v-if="loadingLogs && logs.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <gl-infinite-scroll
      v-else
      :max-list-height="listHeight"
      :fetched-items="logs.length"
      @bottomReached="bottomReached"
    >
      <template #items>
        <logs-table :logs="logs" @reload="fetchLogs" @log-selected="onToggleDrawer" />
      </template>

      <template #default>
        <gl-loading-icon v-if="loadingLogs" size="md" />
        <span v-else data-testid="logs-infinite-scrolling-legend">
          <gl-sprintf v-if="logs.length" :message="$options.i18n.infiniteScrollLegend">
            <template #count>{{ logs.length }}</template>
          </gl-sprintf>
        </span>
      </template>
    </gl-infinite-scroll>

    <logs-drawer :log="selectedLog" :open="Boolean(selectedLog)" @close="closeDrawer" />
  </div>
</template>
