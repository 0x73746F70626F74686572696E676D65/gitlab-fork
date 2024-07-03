<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import MergeTrainsFeedbackBanner from './components/merge_trains_feedback_banner.vue';
import MergeTrainBranchSelector from './components/merge_train_branch_selector.vue';
import MergeTrainTabs from './components/merge_train_tabs.vue';
import MergeTrainsTable from './components/merge_trains_table.vue';
import MergeTrainsEmptyState from './components/merge_trains_empty_state.vue';
import getActiveMergeTrains from './graphql/queries/get_active_merge_trains.query.graphql';
import getCompletedMergeTrains from './graphql/queries/get_completed_merge_trains.query.graphql';
import { DEFAULT_CURSOR, POLL_INTERVAL } from './constants';

const ACTIVE_TAB_INDEX = 0;

export default {
  name: 'MergeTrainsApp',
  components: {
    GlLoadingIcon,
    MergeTrainsFeedbackBanner,
    MergeTrainBranchSelector,
    MergeTrainTabs,
    MergeTrainsTable,
    MergeTrainsEmptyState,
  },
  inject: {
    fullPath: {
      default: '',
    },
    defaultBranch: {
      default: '',
    },
  },
  apollo: {
    activeMergeTrains: {
      query: getActiveMergeTrains,
      variables() {
        return {
          fullPath: this.fullPath,
          targetBranch: this.selectedBranch,
          ...this.activeCursor,
        };
      },
      update(data) {
        const { mergeTrains } = data.project;

        if (mergeTrains.nodes.length > 0) {
          return { train: mergeTrains.nodes[0] };
        }

        return { train: {} };
      },
      error() {
        createAlert({
          message: s__('Pipelines|An error occurred while trying to fetch the active merge train.'),
        });
      },
    },
    completedMergeTrains: {
      query: getCompletedMergeTrains,
      variables() {
        return {
          fullPath: this.fullPath,
          targetBranch: this.selectedBranch,
          ...this.mergedCursor,
        };
      },
      update(data) {
        const { mergeTrains } = data.project;

        if (mergeTrains.nodes.length > 0) {
          return { train: mergeTrains.nodes[0] };
        }

        return { train: {} };
      },
      error() {
        createAlert({
          message: s__(
            'Pipelines|An error occurred while trying to fetch the completed merge train.',
          ),
        });
      },
    },
  },
  data() {
    return {
      activeMergeTrains: { train: {} },
      completedMergeTrains: { train: {} },
      selectedBranch: this.defaultBranch,
      activeCursor: DEFAULT_CURSOR,
      mergedCursor: DEFAULT_CURSOR,
    };
  },
  computed: {
    loading() {
      return (
        this.$apollo.queries.activeMergeTrains.loading ||
        this.$apollo.queries.completedMergeTrains.loading
      );
    },
    hasActiveCars() {
      return this.activeMergeTrains?.train?.cars?.nodes?.length > 0;
    },
    hasMergedCars() {
      return this.completedMergeTrains?.train?.cars?.nodes?.length > 0;
    },
  },
  methods: {
    tabHandler(tabIndex) {
      if (tabIndex === ACTIVE_TAB_INDEX) {
        this.$apollo.queries.activeMergeTrains.startPolling(POLL_INTERVAL);
        this.$apollo.queries.completedMergeTrains.stopPolling();
      } else {
        this.$apollo.queries.completedMergeTrains.startPolling(POLL_INTERVAL);
        this.$apollo.queries.activeMergeTrains.stopPolling();
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="loading" class="gl-float-left gl-mt-5" size="md" />

    <template v-else>
      <merge-trains-feedback-banner />

      <div class="gl-flex gl-justify-between gl-mb-5">
        <h1 class="gl-font-size-h1">{{ s__('Pipelines|Merge train') }}</h1>
        <merge-train-branch-selector
          :selected-branch="selectedBranch"
          @branchChanged="selectedBranch = $event"
        />
      </div>

      <merge-train-tabs
        class="gl-pt-2"
        :active-train="activeMergeTrains.train"
        :merged-train="completedMergeTrains.train"
        @activeTab="tabHandler"
      >
        <template #active>
          <merge-trains-table
            v-if="hasActiveCars"
            :train="activeMergeTrains.train"
            :cursor="activeCursor"
            data-testid="active-merge-trains-table"
            @pageChange="activeCursor = $event"
          />

          <merge-trains-empty-state
            v-else
            :branch="selectedBranch"
            data-testid="active-empty-state"
          />
        </template>
        <template #merged>
          <merge-trains-table
            v-if="hasMergedCars"
            :train="completedMergeTrains.train"
            :cursor="mergedCursor"
            data-testid="completed-merge-trains-table"
            @pageChange="mergedCursor = $event"
          />

          <merge-trains-empty-state
            v-else
            :branch="selectedBranch"
            data-testid="merged-empty-state"
          />
        </template>
      </merge-train-tabs>
    </template>
  </div>
</template>
