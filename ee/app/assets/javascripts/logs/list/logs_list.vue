<script>
import { GlLoadingIcon, GlInfiniteScroll, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { contentTop } from '~/lib/utils/common_utils';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import LogsTable from './logs_table.vue';
import LogsDrawer from './logs_drawer.vue';
import LogsFilteredSearch from './filter_bar/logs_filtered_search.vue';
import { queryToFilterObj, filterObjToQuery, selectedLogQueryObject } from './filter_bar/filters';

const LIST_V_PADDING = 100;
const PAGE_SIZE = 100;

export default {
  components: {
    GlLoadingIcon,
    LogsTable,
    LogsDrawer,
    GlInfiniteScroll,
    GlSprintf,
    LogsFilteredSearch,
    UrlSync,
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
    return {
      loadingLogs: false,
      loadingMetadata: false,
      logs: [],
      metadata: {},
      filters: queryToFilterObj(window.location.search),
      isDrawerOpen: false,
      selectedLog: null,
      nextPageToken: null,
    };
  },
  computed: {
    listHeight() {
      return window.innerHeight - contentTop() - LIST_V_PADDING;
    },
    query() {
      if (this.selectedLog) {
        return selectedLogQueryObject(this.selectedLog);
      }
      return filterObjToQuery(this.filters);
    },
  },
  created() {
    this.fetchLogs();
    this.fetchMetadata();
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
        const log = this.logs.find((s) => s.fingerprint === fingerprint);
        this.selectedLog = log;
      }
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
      this.filters = {
        dateRange,
        attributes,
      };
      this.closeDrawer();
      this.fetchLogs();
      this.fetchMetadata();
    },
  },
};
</script>

<template>
  <div>
    <url-sync :query="query" />

    <div v-if="loadingLogs && logs.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <div v-else class="gl-px-4">
      <logs-filtered-search
        :date-range-filter="filters.dateRange"
        :attributes-filters="filters.attributes"
        @filter="onFilter"
      />

      <gl-infinite-scroll
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
  </div>
</template>
