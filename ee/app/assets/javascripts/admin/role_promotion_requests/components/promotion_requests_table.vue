<script>
import { GlTable } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import UserAvatar from '~/vue_shared/components/users_table/user_avatar.vue';

export default {
  name: 'PromotionRequestsTable',
  components: {
    GlTable,
    UserAvatar,
    UserDate,
  },
  inject: ['paths'],
  props: {
    list: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Name'),
    },
    {
      key: 'requestedRole',
      label: s__('PromotionRequests|Highest role requested'),
    },
    {
      key: 'lastActivity',
      label: __('Last activity'),
    },
  ],
};
</script>

<template>
  <div>
    <gl-table
      :items="list"
      :fields="$options.fields"
      :empty-text="s__('PromotionRequests|No promotion requests found')"
      show-empty
      stacked="md"
      :busy="isLoading"
    >
      <template #cell(name)="{ item: { user } }">
        <user-avatar :user="user" :admin-user-path="paths.adminUser" />
      </template>

      <template #cell(requestedRole)="{ item: { newAccessLevel } }">
        {{ newAccessLevel.stringValue }}
      </template>

      <template #cell(lastActivity)="{ item: { user } }">
        <user-date :date="user.lastActivityOn" />
      </template>
    </gl-table>
  </div>
</template>
