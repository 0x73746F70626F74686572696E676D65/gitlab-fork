<script>
import { GlFormCheckbox, GlLoadingIcon, GlTable, GlSprintf, GlLink, GlAlert } from '@gitlab/ui';
import { pull } from 'lodash';
import { s__ } from '~/locale';
import memberRolePermissionsQuery from 'ee/roles_and_permissions/graphql/member_role_permissions.query.graphql';
import { helpPagePath } from '~/helpers/help_page_helper';

export const FIELDS = [
  { key: 'checkbox', label: '' },
  { key: 'name', label: s__('MemberRole|Permission') },
  { key: 'description', label: s__('MemberRole|Description') },
];

export default {
  i18n: {
    customPermissionsLabel: s__('MemberRole|Custom permissions'),
    customPermissionsDescription: s__(
      'MemberRole|Learn more about %{linkStart}available custom permissions%{linkEnd}.',
    ),
    permissionsFetchError: s__('MemberRole|Could not fetch available permissions.'),
    permissionsSelected: s__('MemberRole|%{count} of %{total} permissions selected'),
    permissionsSelectionError: s__('MemberRole|Select at least one permission.'),
  },
  components: {
    GlFormCheckbox,
    GlLoadingIcon,
    GlLink,
    GlSprintf,
    GlTable,
    GlAlert,
  },
  model: {
    prop: 'permissions',
    event: 'change',
  },
  props: {
    permissions: {
      type: Array,
      required: true,
    },
    isValid: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      availablePermissions: [],
    };
  },
  apollo: {
    availablePermissions: {
      query: memberRolePermissionsQuery,
      update(data) {
        return data.memberRolePermissions?.nodes || [];
      },
      error() {
        this.availablePermissions = [];
      },
    },
  },
  computed: {
    docsPath() {
      return helpPagePath('user/custom_roles/abilities');
    },
    isLoadingPermissions() {
      return this.$apollo.queries.availablePermissions.loading;
    },
    isErrorLoadingPermissions() {
      return !this.isLoadingPermissions && !this.hasAvailablePermissions;
    },
    hasAvailablePermissions() {
      return this.availablePermissions.length > 0;
    },
    isSomePermissionsSelected() {
      return this.permissions.length > 0 && !this.isAllPermissionsSelected;
    },
    isAllPermissionsSelected() {
      return (
        !this.isLoadingPermissions && this.permissions.length >= this.availablePermissions.length
      );
    },
    parentPermissionsLookup() {
      return this.availablePermissions.reduce((acc, { value, requirements }) => {
        if (requirements) {
          acc[value] = requirements;
        }

        return acc;
      }, {});
    },
    childPermissionsLookup() {
      return this.availablePermissions.reduce((acc, { value, requirements }) => {
        requirements?.forEach((requirement) => {
          // Create the array if it doesn't exist, then add the requirement to it.
          acc[requirement] = acc[requirement] || [];
          acc[requirement].push(value);
        });

        return acc;
      }, {});
    },
  },
  methods: {
    isSelected({ value }) {
      return this.permissions.includes(value);
    },
    updatePermissions({ value }) {
      const selected = [...this.permissions];

      if (selected.includes(value)) {
        // Permission is being removed, remove it and deselect any child permissions.
        pull(selected, value);
        this.deselectChildPermissions(value, selected);
      } else {
        // Permission is being added, select it and select any parent permissions.
        selected.push(value);
        this.selectParentPermissions(value, selected);
      }

      this.emitPermissionsUpdate(selected);
    },
    toggleAllPermissions() {
      const permissions = this.isAllPermissionsSelected ? [] : this.availablePermissions;
      this.emitPermissionsUpdate(permissions.map(({ value }) => value));
    },
    emitPermissionsUpdate(permissions) {
      this.$emit('change', permissions);
    },
    selectParentPermissions(permission, selected) {
      const parentPermissions = this.parentPermissionsLookup[permission];

      parentPermissions?.forEach((parent) => {
        // Only select the parent permission if it's not selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (!selected.includes(parent)) {
          selected.push(parent);
          this.selectParentPermissions(parent, selected);
        }
      });
    },
    deselectChildPermissions(permission, selected) {
      const childPermissions = this.childPermissionsLookup[permission];

      childPermissions?.forEach((child) => {
        // Only unselect the child permission if it's already selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (selected.includes(child)) {
          pull(selected, child);
          this.deselectChildPermissions(child, selected);
        }
      });
    },
  },
  FIELDS,
};
</script>

<template>
  <fieldset>
    <legend class="gl-mb-1 gl-border-b-0 gl-font-base">
      <span class="gl-font-bold">{{ $options.i18n.customPermissionsLabel }}</span>
      <span
        v-if="hasAvailablePermissions"
        class="gl-text-gray-400 gl-ml-3"
        data-testid="permissions-selected-message"
      >
        <gl-sprintf :message="$options.i18n.permissionsSelected">
          <template #count>{{ permissions.length }}</template>
          <template #total>{{ availablePermissions.length }}</template>
        </gl-sprintf>
      </span>
    </legend>

    <p class="gl-mb-4">
      <gl-sprintf :message="$options.i18n.customPermissionsDescription">
        <template #link="{ content }">
          <gl-link :href="docsPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <p v-if="!isValid" class="gl-text-red-500">{{ $options.i18n.permissionsSelectionError }}</p>

    <gl-alert
      v-if="isErrorLoadingPermissions"
      :dismissible="false"
      variant="danger"
      class="gl-mb-6 gl-display-inline-block"
    >
      {{ $options.i18n.permissionsFetchError }}
    </gl-alert>

    <gl-table
      v-else
      :items="availablePermissions"
      :fields="$options.FIELDS"
      :busy="isLoadingPermissions"
      hover
      selected-variant=""
      selectable
      class="gl-my-8"
      @row-clicked="updatePermissions"
    >
      <template #table-busy>
        <gl-loading-icon size="md" />
      </template>

      <template #head(checkbox)>
        <gl-form-checkbox
          :disabled="isLoadingPermissions"
          :checked="isAllPermissionsSelected"
          :indeterminate="isSomePermissionsSelected"
          @change="toggleAllPermissions"
        />
      </template>

      <template #cell(checkbox)="{ item }">
        <gl-form-checkbox :checked="isSelected(item)" @change="updatePermissions(item)" />
      </template>

      <template #cell(name)="{ item }">
        <span :class="{ 'gl-text-red-500': !isValid }" class="gl-whitespace-nowrap">
          {{ item.name }}
        </span>
      </template>
    </gl-table>
  </fieldset>
</template>
