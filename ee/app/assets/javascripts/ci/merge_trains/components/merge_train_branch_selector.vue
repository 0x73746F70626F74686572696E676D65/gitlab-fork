<script>
import RefSelector from '~/ref/components/ref_selector.vue';
import { REF_TYPE_BRANCHES } from '~/ref/constants';

export default {
  name: 'MergeTrainBranchSelector',
  ENABLED_REF_TYPES: [REF_TYPE_BRANCHES],
  components: {
    RefSelector,
  },
  inject: {
    projectId: {
      default: '',
    },
  },
  props: {
    selectedBranch: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      branch: this.selectedBranch,
    };
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-mt-3">
    <span class="gl-mr-3">{{ s__('Pipelines|Filter by target branch') }}</span>
    <ref-selector
      :value="branch"
      :project-id="projectId"
      :enabled-ref-types="$options.ENABLED_REF_TYPES"
      @input="$emit('branchChanged', $event)"
    />
  </div>
</template>
