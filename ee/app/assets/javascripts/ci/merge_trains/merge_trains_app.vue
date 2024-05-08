<script>
import MergeTrainTabs from './components/merge_train_tabs.vue';
import MergeTrainsTable from './components/merge_trains_table.vue';

export default {
  name: 'MergeTrainsApp',
  components: {
    MergeTrainTabs,
    MergeTrainsTable,
  },
  inject: {
    fullPath: {
      default: '',
    },
  },
};
</script>

<template>
  <div>
    <h1 class="gl-font-size-h1 gl-mb-5">{{ s__('Pipelines|Merge train') }}</h1>

    <merge-train-tabs class="gl-pt-2">
      <template #active>
        <merge-trains-table />
      </template>
      <template #merged>
        <merge-trains-table />
      </template>
    </merge-train-tabs>
  </div>
</template>
