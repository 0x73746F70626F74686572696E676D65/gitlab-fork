<script>
import { isEmpty } from 'lodash';
import { GlLink, GlSkeletonLoader, GlAlert } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import DoraPerformersScoreCard from 'ee/analytics/dashboards/dora_performers_score/components/dora_performers_score_card.vue';
import {
  DASHBOARD_TITLE,
  DASHBOARD_DESCRIPTION,
  DASHBOARD_DOCS_LINK,
  YAML_CONFIG_LOAD_ERROR,
} from '../../constants';
import { fetchYamlConfig } from '../../yaml_utils';
import DoraVisualization from '../../components/dora_visualization.vue';
import FeedbackBanner from '../../components/value_stream_feedback_banner.vue';

const pathsToPanels = (paths) =>
  paths.map(({ namespace, isProject = false }) => ({ data: { namespace }, isProject }));

export default {
  name: 'DashboardsApp',
  components: {
    GlAlert,
    GlLink,
    GlSkeletonLoader,
    DoraVisualization,
    DoraPerformersScoreCard,
    FeedbackBanner,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    queryPaths: {
      type: Array,
      required: false,
      default: () => [],
    },
    yamlConfigProject: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    learnMore: __('Learn more'),
  },
  data: () => ({
    loading: true,
    yamlConfig: {},
    projects: [],
  }),
  computed: {
    dashboardTitle() {
      return this.yamlConfig?.title || DASHBOARD_TITLE;
    },
    dashboardDescription() {
      return this.yamlConfig?.description || DASHBOARD_DESCRIPTION;
    },
    isDefaultDescription() {
      return this.dashboardDescription === DASHBOARD_DESCRIPTION;
    },
    defaultPanels() {
      return pathsToPanels([{ namespace: this.fullPath }]);
    },
    queryPanels() {
      return pathsToPanels(this.queryPaths);
    },
    panels() {
      let list = this.defaultPanels;
      if (!isEmpty(this.queryPanels)) {
        list = list.concat(this.queryPanels);
      } else if (!isEmpty(this.yamlConfig?.panels)) {
        list = this.yamlConfig?.panels;
      }

      return list;
    },
    groupPanels() {
      return this.panels.filter(({ isProject }) => !isProject);
    },
    loadError() {
      if (!this.yamlConfigProject?.id || this.yamlConfig) return '';

      const { fullPath } = this.yamlConfigProject;
      return sprintf(YAML_CONFIG_LOAD_ERROR, { fullPath });
    },
  },
  async mounted() {
    this.yamlConfig = await fetchYamlConfig(this.yamlConfigProject?.id);
    this.loading = false;
  },
  DASHBOARD_DOCS_LINK,
};
</script>
<template>
  <div data-testid="legacy-vsd">
    <feedback-banner />

    <div v-if="loading" class="gl-mt-5">
      <gl-skeleton-loader :lines="2" />
    </div>
    <div v-else>
      <gl-alert
        v-if="loadError"
        data-testid="alert-error"
        class="gl-mt-5"
        variant="warning"
        :dismissible="false"
      >
        {{ loadError }}
      </gl-alert>

      <h3 class="page-title" data-testid="dashboard-title">{{ dashboardTitle }}</h3>
      <p data-testid="dashboard-description">
        {{ dashboardDescription }}
        <gl-link v-if="isDefaultDescription" :href="$options.DASHBOARD_DOCS_LINK" target="_blank">
          {{ $options.i18n.learnMore }}.
        </gl-link>
      </p>

      <dora-visualization
        v-for="({ title, data }, index) in panels"
        :key="index"
        :title="title"
        :data="data"
        :full-path="data.namespace"
        data-testid="panel-dora-chart"
      />

      <dora-performers-score-card
        v-for="({ data }, index) in groupPanels"
        :key="`dora-performers-score-card-${index}`"
        :data="data"
        class="gl-mt-5"
        data-testid="panel-dora-performers-score"
      />
    </div>
  </div>
</template>
