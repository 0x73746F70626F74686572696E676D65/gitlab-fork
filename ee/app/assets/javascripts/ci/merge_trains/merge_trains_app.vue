<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import MergeTrainsFeedbackBanner from './components/merge_trains_feedback_banner.vue';
import MergeTrainBranchSelector from './components/merge_train_branch_selector.vue';
import MergeTrainTabs from './components/merge_train_tabs.vue';
import MergeTrainsTable from './components/merge_trains_table.vue';
import getActiveMergeTrains from './graphql/queries/get_active_merge_trains.query.graphql';
import getCompletedMergeTrains from './graphql/queries/get_completed_merge_trains.query.graphql';

export default {
  name: 'MergeTrainsApp',
  components: {
    GlLoadingIcon,
    MergeTrainsFeedbackBanner,
    MergeTrainBranchSelector,
    MergeTrainTabs,
    MergeTrainsTable,
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
          targetBranch: this.defaultBranch,
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
          targetBranch: this.defaultBranch,
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
    };
  },
  computed: {
    loading() {
      return (
        this.$apollo.queries.activeMergeTrains.loading ||
        this.$apollo.queries.completedMergeTrains.loading
      );
    },
  },
  methods: {
    fetchNewTrain(branchName) {
      this.selectedBranch = branchName;
      this.$apollo.queries.activeMergeTrains.refetch({ targetBranch: branchName });
      this.$apollo.queries.completedMergeTrains.refetch({ targetBranch: branchName });
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
          @branchChanged="fetchNewTrain"
        />
      </div>

      <merge-train-tabs
        class="gl-pt-2"
        :active-train="activeMergeTrains.train"
        :merged-train="completedMergeTrains.train"
      >
        <template #active>
          <merge-trains-table :train="activeMergeTrains.train" />
        </template>
        <template #merged>
          <merge-trains-table :train="completedMergeTrains.train" />
        </template>
      </merge-train-tabs>
    </template>
  </div>
</template>
