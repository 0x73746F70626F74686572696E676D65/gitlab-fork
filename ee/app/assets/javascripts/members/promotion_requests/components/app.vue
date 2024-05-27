<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { GlTableLite } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import MembersPagination from '~/members/components/table/members_pagination.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import UserAvatar from '~/members/components/avatars/user_avatar.vue';

const FIELDS = [
  {
    key: 'user',
    label: __('User'),
  },
  {
    key: 'requested_role',
    label: s__('Members|Requested Role'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_by',
    label: s__('Members|Requested By'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_on',
    label: s__('Members|Requested On'),
    tdClass: '!gl-align-middle',
  },
];

export default {
  name: 'PromotionRequestsTabApp',
  components: {
    MembersPagination,
    GlTableLite,
    UserDate,
    UserAvatar,
  },
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
      users(state) {
        return state[this.namespace].data;
      },
      pagination(state) {
        return state[this.namespace].pagination;
      },
    }),
    currentUserId() {
      return gon.current_user_id;
    },
  },
  FIELDS,
};
</script>
<template>
  <div>
    <gl-table-lite :items="users" :fields="$options.FIELDS">
      <template #cell(user)="{ item }">
        <user-avatar :member="item" :is-current-user="item.user.id === currentUserId" />
      </template>
      <template #cell(requested_role)="{ item }">
        {{ item.newAccessLevel.stringValue }}
      </template>
      <template #cell(requested_by)="{ item }">
        <a :href="item.requestedBy.webUrl">{{ item.requestedBy.name }}</a>
      </template>
      <template #cell(requested_on)="{ item }">
        <user-date :date="item.createdAt" />
      </template>
    </gl-table-lite>
    <members-pagination :pagination="pagination" :tab-query-param-value="tabQueryParamValue" />
  </div>
</template>
