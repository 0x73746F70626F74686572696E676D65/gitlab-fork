<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import MembersPagination from '~/members/components/table/members_pagination.vue';

export default {
  name: 'PromotionRequestsTabApp',
  components: { MembersPagination },
  props: {
    namespace: {
      type: String,
      required: true,
    },
    tabQueryParamValue: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState({
      data(state) {
        return state[this.namespace].data;
      },
      pagination(state) {
        return state[this.namespace].pagination;
      },
    }),
  },
};
</script>
<template>
  <div>
    <ul>
      <li v-for="request in data" :key="request.id">
        {{ request.user.name }}
      </li>
    </ul>
    <members-pagination :pagination="pagination" :tab-query-param-value="tabQueryParamValue" />
  </div>
</template>
