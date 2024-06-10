<script>
import {
  GlLoadingIcon,
  GlInfiniteScroll,
  GlFilteredSearchToken,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, joinPaths, setUrlParams, DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';
import { isMetaClick, contentTop } from '~/lib/utils/common_utils';
import { sanitize } from '~/lib/dompurify';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { logError } from '~/lib/logger';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
} from './filters';
import MetricsTable from './metrics_table.vue';

const LIST_VERTICAL_PADDING = 130; // search bar height + some more v padding
const LIST_SEARCH_LIMIT = 50;

export default {
  components: {
    PageHeading,
    GlLoadingIcon,
    MetricsTable,
    GlInfiniteScroll,
    FilteredSearch,
    UrlSync,
    GlLink,
    GlSprintf,
  },
  i18n: {
    searchInputPlaceholder: s__('ObservabilityMetrics|Search metrics...'),
    attributeFilterTitle: s__('ObservabilityMetrics|Attribute'),
    pageTitle: s__(`ObservabilityMetrics|Metrics`),
    description: s__(
      `ObservabilityMetrics|Track health data from your systems. Send metric data to this project using OpenTelemetry. %{docsLink}`,
    ),
    docsLinkText: s__(`ObservabilityMetrics|Learn more.`),
  },
  docsLink: `${DOCS_URL_IN_EE_DIR}/operations/metrics`,
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      loading: false,
      metrics: [],
      allAttributes: [],
      filters: queryToFilterObj(window.location.search),
    };
  },
  computed: {
    listHeight() {
      return window.innerHeight - contentTop() - LIST_VERTICAL_PADDING;
    },
    query() {
      return filterObjToQuery(this.filters);
    },
    initialFilterValue() {
      return filterObjToFilterToken(this.filters);
    },
    availableAttributes() {
      return this.allAttributes.map((attribute) => ({
        value: attribute,
        title: attribute,
      }));
    },
    tokens() {
      return [
        {
          title: this.$options.i18n.attributeFilterTitle,
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
          options: this.availableAttributes,
        },
      ];
    },
  },
  created() {
    this.fetchMetrics();
  },
  methods: {
    async fetchMetrics() {
      this.loading = true;
      try {
        const {
          metrics,
          all_available_attributes: allAttributes = [],
        } = await this.observabilityClient.fetchMetrics({
          filters: this.filters,
          limit: LIST_SEARCH_LIMIT,
        });
        this.metrics = metrics;
        this.allAttributes = allAttributes;
      } catch (e) {
        createAlert({
          message: s__('ObservabilityMetrics|Failed to load metrics.'),
        });
      } finally {
        this.loading = false;
      }
    },
    onMetricClicked({ metricId, clickEvent = {} }) {
      const external = isMetaClick(clickEvent);
      const metricType = this.metrics.find((m) => m.name === metricId)?.type;
      if (!metricType) {
        logError(
          new Error(`onMetricClicked() - Could not find metric type for metric ${metricId}`),
        );
        return;
      }
      const url = joinPaths(
        window.location.origin,
        window.location.pathname,
        encodeURIComponent(metricId),
      );
      const fullUrl = setUrlParams({ type: encodeURIComponent(metricType) }, url);
      visitUrl(sanitize(fullUrl), external);
    },
    onFilter(filterTokens) {
      this.filters = filterTokensToFilterObj(filterTokens);
      this.metrics = [];
      this.allAttributes = [];

      this.fetchMetrics();
    },
  },
};
</script>

<template>
  <div class="gl-mx-7">
    <div v-if="loading && metrics.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <template v-else>
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

      <div class="vue-filtered-search-bar-container gl-border-t-none gl-my-6">
        <filtered-search
          :initial-filter-value="initialFilterValue"
          recent-searches-storage-key="recent-metrics-filter-search"
          namespace="metrics-list-filtered-search"
          :tokens="tokens"
          :search-input-placeholder="$options.i18n.searchInputPlaceholder"
          terms-as-tokens
          @onFilter="onFilter"
        />
      </div>

      <gl-loading-icon v-if="loading && metrics.length > 0" size="lg" />
      <gl-infinite-scroll v-else :fetched-items="metrics.length" :max-list-height="listHeight">
        <template #items>
          <metrics-table :metrics="metrics" @metric-clicked="onMetricClicked" />
        </template>
        <template #default>
          <!-- Override default footer -->
          <span data-testid="metrics-infinite-scrolling-legend"></span>
        </template>
      </gl-infinite-scroll>
    </template>
  </div>
</template>
