<script>
import { GlTable } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ACCESS_LEVEL_LABELS } from '~/access_level/constants';
import { TABLE_FIELDS } from '../constants';
import CustomRolesActions from './custom_roles_actions.vue';

export default {
  components: {
    GlTable,
    CustomRolesActions,
  },
  props: {
    customRoles: {
      type: Array,
      required: true,
    },
  },
  methods: {
    getBaseRoleName({ integerValue }) {
      return ACCESS_LEVEL_LABELS[integerValue];
    },
  },
  TABLE_FIELDS,
  getIdFromGraphQLId,
};
</script>

<template>
  <gl-table :fields="$options.TABLE_FIELDS" :items="customRoles" stacked="md">
    <template #cell(id)="{ item: { id } }">
      {{ $options.getIdFromGraphQLId(id) }}
    </template>

    <template #cell(description)="{ item: { description } }">
      <template v-if="description">{{ description }}</template>
      <span v-else class="gl-text-gray-400">{{ s__('MemberRole|No description') }}</span>
    </template>

    <template #cell(baseRole)="{ item: { baseAccessLevel } }">
      {{ getBaseRoleName(baseAccessLevel) }}
    </template>

    <template #cell(permissions)="{ item: { enabledPermissions } }">
      <div v-for="{ value, name } in enabledPermissions.nodes" :key="value" class="gl-mb-2">
        {{ name }}
      </div>
    </template>

    <template #cell(actions)="{ item }">
      <custom-roles-actions :custom-role="item" @delete="$emit('delete-role', item)" />
    </template>
  </gl-table>
</template>
