<script>
import { uniqBy } from 'lodash';
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { USER_TYPE } from 'ee/security_orchestration/constants';
import { isProject } from 'ee/security_orchestration/components/utils';
import { renderMultiSelectText } from '../../utils';

const createUserObject = (user) => ({
  ...user,
  text: user.name,
  username: `@${user.username}`,
  value: user.value || user.id,
});

export default {
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    existingApprovers: {
      type: Array,
      required: false,
      default: () => [],
    },
    state: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  apollo: {
    users: {
      query() {
        return isProject(this.namespaceType) ? searchProjectMembers : searchGroupMembers;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          search: this.search,
        };
      },
      update(data) {
        const nodes = isProject(this.namespaceType)
          ? data?.project?.projectMembers?.nodes
          : data?.workspace?.users?.nodes;

        const users = (nodes || []).map(({ user }) => createUserObject(user));
        return uniqBy(users, 'id');
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    },
  },
  data() {
    return {
      selectedUsers: this.existingApprovers.map((a) => createUserObject(a)),
      search: '',
      users: [],
    };
  },
  computed: {
    selectedUsersValues() {
      return this.selectedUsers.map((u) => u.value);
    },
    userItems() {
      return this.users.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedUsersValues,
        items: this.userItems,
        itemTypeName: __('users'),
        useAllSelected: false,
        useSingleOption: true,
      });
    },
  },
  methods: {
    handleSelectedUser(usersIds) {
      const updatedSelectedUsers = this.createSelectedUsers(usersIds);

      this.selectedUsers = updatedSelectedUsers;
      this.$emit('updateSelectedApprovers', updatedSelectedUsers);
    },
    createSelectedUsers(usersIds) {
      let updatedSelectedUsers = [...this.selectedUsers];

      const isAddingUser = this.selectedUsers.length < usersIds.length;
      if (isAddingUser) {
        const newUser = this.users.find((u) => u.value === usersIds[usersIds.length - 1]);
        updatedSelectedUsers.push({
          ...newUser,
          type: USER_TYPE,
          id: getIdFromGraphQLId(newUser.value),
        });
      } else {
        updatedSelectedUsers = this.selectedUsers.filter((selectedUser) =>
          usersIds.includes(selectedUser.value),
        );
      }

      return updatedSelectedUsers;
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="users"
    block
    searchable
    is-check-centered
    multiple
    :toggle-class="['gl-max-w-30', { '!gl-shadow-inner-1-red-500': !state }]"
    :searching="$apollo.loading"
    :selected="selectedUsersValues"
    :toggle-text="toggleText"
    @search="search = $event"
    @select="handleSelectedUser"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        shape="circle"
        :size="32"
        :src="item.avatarUrl"
        :label="item.text"
        :sub-label="item.username"
      />
    </template>
  </gl-collapsible-listbox>
</template>
