<script>
import { GlCard, GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import {
  DORA_PERFORMERS_SCORE_DEFAULT_PANEL_TITLE,
  DORA_PERFORMERS_SCORE_GROUP_ERROR,
} from '../constants';
import getDoraPerformersGroup from '../graphql/get_dora_performers_group.query.graphql';
import DoraPerformersScoreChart from './dora_performers_score_chart.vue';

export default {
  name: 'DoraPerformersScoreCard',
  components: {
    GlCard,
    GlAlert,
    GlSkeletonLoader,
    DoraPerformersScoreChart,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  data() {
    return { group: null, chartError: null };
  },
  apollo: {
    group: {
      query: getDoraPerformersGroup,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      skip() {
        return !this.fullPath;
      },
      update({ group }) {
        return group;
      },
    },
  },
  computed: {
    fullPath() {
      return this.data?.namespace;
    },
    isLoading() {
      return this.$apollo.queries.group.loading;
    },
    errorMessage() {
      if (this.chartError) return this.chartError;
      if (this.isLoading || this.group) return '';

      const { fullPath } = this;
      return sprintf(DORA_PERFORMERS_SCORE_GROUP_ERROR, { fullPath });
    },
    panelTitle() {
      if (this.errorMessage) {
        return DORA_PERFORMERS_SCORE_DEFAULT_PANEL_TITLE;
      }

      return sprintf(this.$options.i18n.title, { namespaceName: this.group?.name });
    },
  },
  methods: {
    handleChartError(error) {
      this.chartError = error;
    },
  },
  i18n: {
    title: s__('Analytics|DORA performers score for %{namespaceName} group'),
  },
};
</script>

<template>
  <gl-card header-class="gl-bg-transparent gl-border-none" body-class="gl-pt-0">
    <template #header>
      <gl-skeleton-loader v-if="isLoading" :lines="1" :width="450" />
      <div v-else class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
        <h5
          data-testid="dora-performers-score-panel-title"
          class="gl-my-0 gl-display-flex gl-gap-3 gl-align-items-center"
        >
          {{ panelTitle }}
        </h5>
      </div>
    </template>

    <gl-alert v-if="errorMessage" variant="danger" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>
    <dora-performers-score-chart v-else-if="!isLoading" :data="data" @error="handleChartError" />
  </gl-card>
</template>
