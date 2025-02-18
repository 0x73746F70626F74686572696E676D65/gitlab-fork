<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { GlAlert, GlIcon, GlTooltip } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { generateFilterTextDescription } from '../utils';
import { formattedDate } from '../../shared/utils';
import { TASKS_BY_TYPE_SUBJECT_ISSUE, TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS } from '../constants';
import TasksByTypeChart from './tasks_by_type/chart.vue';
import TasksByTypeFilters from './tasks_by_type/filters.vue';
import NoDataAvailableState from './no_data_available_state.vue';

export default {
  name: 'TypeOfWorkCharts',
  components: {
    ChartSkeletonLoader,
    GlAlert,
    GlIcon,
    GlTooltip,
    TasksByTypeChart,
    TasksByTypeFilters,
    NoDataAvailableState,
  },
  directives: {
    SafeHtml,
  },
  computed: {
    ...mapState('typeOfWork', [
      'isLoadingTasksByTypeChart',
      'isLoadingTasksByTypeChartTopLabels',
      'errorMessage',
    ]),
    ...mapGetters('typeOfWork', [
      'selectedTasksByTypeFilters',
      'tasksByTypeChartData',
      'selectedLabelNames',
    ]),
    hasData() {
      return Boolean(this.tasksByTypeChartData?.data.length);
    },
    isLoading() {
      return Boolean(this.isLoadingTasksByTypeChart || this.isLoadingTasksByTypeChartTopLabels);
    },
    tooltipText() {
      const {
        selectedTasksByTypeFilters: {
          createdAfter,
          createdBefore,
          namespace: { name: groupName },
          selectedProjectIds,
        },
      } = this;

      return generateFilterTextDescription({
        groupName,
        selectedLabelsCount: this.selectedLabelNames.length,
        selectedProjectsCount: selectedProjectIds.length,
        selectedSubjectFilterText: this.selectedSubjectFilterText.toLowerCase(),
        createdAfter: formattedDate(createdAfter),
        createdBefore: formattedDate(createdBefore),
      });
    },
    selectedSubjectFilter() {
      const {
        selectedTasksByTypeFilters: { subject },
      } = this;
      return subject || TASKS_BY_TYPE_SUBJECT_ISSUE;
    },
    selectedSubjectFilterText() {
      const { selectedSubjectFilter } = this;
      return (
        TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[selectedSubjectFilter] ||
        TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[TASKS_BY_TYPE_SUBJECT_ISSUE]
      );
    },
  },
  methods: {
    ...mapActions('typeOfWork', ['setTasksByTypeFilters']),
    onUpdateFilter(e) {
      this.setTasksByTypeFilters(e);
    },
  },
};
</script>
<template>
  <div class="js-tasks-by-type-chart">
    <chart-skeleton-loader v-if="isLoading" class="gl-my-4 gl-py-4" />
    <div v-else>
      <div class="gl-display-flex gl-justify-content-space-between">
        <h4 class="gl-mt-0">
          {{ s__('ValueStreamAnalytics|Tasks by type') }}&nbsp;
          <span ref="tooltipTrigger" data-testid="vsa-task-by-type-description">
            <gl-icon name="information-o" />
          </span>
          <gl-tooltip :target="() => $refs.tooltipTrigger" boundary="viewport" placement="top">
            <span v-safe-html="tooltipText"></span>
          </gl-tooltip>
        </h4>
        <tasks-by-type-filters
          :selected-label-names="selectedLabelNames"
          :subject-filter="selectedSubjectFilter"
          @update-filter="onUpdateFilter"
        />
      </div>
      <tasks-by-type-chart
        v-if="hasData"
        :data="tasksByTypeChartData.data"
        :group-by="tasksByTypeChartData.groupBy"
      />
      <gl-alert v-else-if="errorMessage" variant="info" :dismissible="false" class="gl-mt-3">
        {{ errorMessage }}
      </gl-alert>
      <no-data-available-state v-else />
    </div>
  </div>
</template>
