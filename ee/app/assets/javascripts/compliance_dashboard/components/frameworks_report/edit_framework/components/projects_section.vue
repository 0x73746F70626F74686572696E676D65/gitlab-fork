<script>
import { GlLink, GlLoadingIcon, GlTable } from '@gitlab/ui';

import { sprintf } from '~/locale';
import { i18n } from '../constants';

import EditSection from './edit_section.vue';

export default {
  components: {
    EditSection,

    GlLink,
    GlLoadingIcon,
    GlTable,
  },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
  },
  computed: {
    description() {
      const { length: count } = this.projects;

      return [sprintf(i18n.projectsTotalCount(count), { count })].join(' ');
    },

    projects() {
      return this.complianceFramework.projects.nodes;
    },
  },
  tableFields: [
    {
      key: 'name',
      label: i18n.projectsTableFields.name,
    },
    {
      key: 'description',
      label: i18n.policiesTableFields.desc,
    },
    {
      key: 'edit',
      label: '',
      thClass: 'gl-w-1',
      tdClass: 'gl-text-right',
    },
  ],
  i18n,
};
</script>
<template>
  <edit-section :title="$options.i18n.projects" :description="description" expandable>
    <gl-table
      v-if="projects.length"
      ref="projectsTable"
      :items="projects"
      :fields="$options.tableFields"
      responsive
      stacked="md"
      hover
      select-mode="single"
      selected-variant="primary"
    >
      <template #cell(name)="{ item }">
        {{ item.name }}
      </template>
      <template #cell(description)="{ item }">
        {{ item.description }}
      </template>
      <template #cell(edit)="{ item }">
        <gl-link :href="item.webUrl">
          {{ __('View') }}
        </gl-link>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
  </edit-section>
</template>
