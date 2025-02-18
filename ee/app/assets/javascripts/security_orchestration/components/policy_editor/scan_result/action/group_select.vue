<script>
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import searchNamespaceGroups from 'ee/security_orchestration/graphql/queries/get_namespace_groups.query.graphql';
import searchDescendantGroups from 'ee/security_orchestration/graphql/queries/get_descendant_groups.query.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { GROUP_TYPE } from 'ee/security_orchestration/constants';
import { renderMultiSelectText } from '../../utils';

const createGroupObject = (group) => ({
  ...group,
  text: group.fullName,
  value: group.value || group.id,
});

export default {
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  inject: ['globalGroupApproversEnabled', 'rootNamespacePath'],
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
    groups: {
      query() {
        return this.globalGroupApproversEnabled ? searchNamespaceGroups : searchDescendantGroups;
      },
      variables() {
        return {
          rootNamespacePath: this.rootNamespacePath,
          search: this.search,
        };
      },
      update(data) {
        if (!this.globalGroupApproversEnabled) {
          const { __typename, avatarUrl, id, fullName, fullPath } = data.group;
          const rootGroupMatches = fullName.includes(this.search);

          const descendantGroups = (data?.group?.descendantGroups?.nodes || []).map(
            createGroupObject,
          );

          if (!rootGroupMatches) return descendantGroups;

          const rootGroup = createGroupObject({ __typename, avatarUrl, id, fullName, fullPath });
          return [rootGroup, ...descendantGroups];
        }

        return (data?.groups?.nodes || []).map(createGroupObject);
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    },
  },
  data() {
    return {
      groups: [],
      selectedGroups: this.existingApprovers.map(createGroupObject),
      search: '',
    };
  },
  computed: {
    selectedGroupsValues() {
      return this.selectedGroups.map((g) => g.value);
    },
    groupItems() {
      return this.groups.reduce((acc, { id, fullName }) => {
        acc[id] = fullName;
        return acc;
      }, {});
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedGroupsValues,
        items: this.groupItems,
        itemTypeName: __('groups'),
        useAllSelected: false,
      });
    },
  },
  methods: {
    createSelectedGroups(groupsIds) {
      let updatedSelectedGroups = [...this.selectedGroups];

      const isAddingGroup = this.selectedGroups.length < groupsIds.length;
      if (isAddingGroup) {
        const newGroup = this.groups.find((g) => g.value === groupsIds[groupsIds.length - 1]);
        updatedSelectedGroups.push({
          ...newGroup,
          type: GROUP_TYPE,
          id: getIdFromGraphQLId(newGroup.value),
        });
      } else {
        updatedSelectedGroups = this.selectedGroups.filter((selectedGroup) =>
          groupsIds.includes(selectedGroup.value),
        );
      }

      return updatedSelectedGroups;
    },
    handleSelectedGroup(groupsIds) {
      const updatedSelectedGroups = this.createSelectedGroups(groupsIds);

      this.selectedGroups = updatedSelectedGroups;
      this.$emit('updateSelectedApprovers', updatedSelectedGroups);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="groups"
    block
    searchable
    is-check-centered
    multiple
    :toggle-class="[{ '!gl-shadow-inner-1-red-500': !state }]"
    :searching="$apollo.loading"
    :selected="selectedGroupsValues"
    :toggle-text="toggleText"
    @search="search = $event"
    @select="handleSelectedGroup"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        shape="circle"
        :size="32"
        :src="item.avatarUrl"
        :entity-name="item.text"
        :label="item.text"
        :sub-label="item.fullPath"
      />
    </template>
  </gl-collapsible-listbox>
</template>
