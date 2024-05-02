<script>
import { GlKeysetPagination } from '@gitlab/ui';

export default {
  components: {
    GlKeysetPagination,
  },
  props: {
    pageInfo: {
      type: Object,
      required: true,
    },
    pageSize: {
      type: Number,
      required: true,
    },
  },
  methods: {
    nextPage() {
      this.$emit('input', {
        after: this.pageInfo.endCursor,
        first: this.pageSize,
      });
    },
    previousPage() {
      this.$emit('input', {
        before: this.pageInfo.startCursor,
        first: this.pageSize,
      });
    },
  },
};
</script>
<template>
  <div
    v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
    class="gl-display-flex gl-justify-content-center gl-mt-3"
  >
    <gl-keyset-pagination
      :has-next-page="pageInfo.hasNextPage"
      :has-previous-page="pageInfo.hasPreviousPage"
      @prev="previousPage"
      @next="nextPage"
    />
  </div>
</template>
