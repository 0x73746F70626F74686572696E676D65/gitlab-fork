<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { GlTableLite, GlAvatarLabeled, GlAvatarLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import MembersPagination from '~/members/components/table/members_pagination.vue';
import UserDate from '~/vue_shared/components/user_date.vue';

export const FIELDS = [
  {
    key: 'user',
    label: s__('Members|User'),
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
    GlAvatarLabeled,
    GlAvatarLink,
    GlTableLite,
    UserDate,
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
  },
  FIELDS,
};
</script>
<template>
  <div>
    <gl-table-lite :items="users" :fields="$options.FIELDS">
      <template #cell(user)="{ item: { user } }">
        <gl-avatar-link target="blank" :href="user.web_url">
          <gl-avatar-labeled
            :src="user.avatar_url"
            :size="32"
            :label="user.name"
            :sub-label="user.username"
          />
        </gl-avatar-link>
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
