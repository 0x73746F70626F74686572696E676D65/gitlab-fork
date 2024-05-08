<script>
import { GlTableLite } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'MergeTrainsTable',
  fields: [
    {
      key: 'mr',
      label: __('Merge request'),
      thClass: 'gl-border-t-none!',
      columnClass: 'gl-w-90p',
    },
    {
      key: 'actions',
      label: '',
      thClass: 'gl-border-t-none!',
      tdClass: 'gl-text-right',
      columnClass: 'gl-w-10p',
    },
  ],
  components: {
    GlTableLite,
  },
  data() {
    return {
      items: [],
    };
  },
};
</script>

<template>
  <gl-table-lite :items="items" :fields="$options.fields">
    <template #table-colgroup="{ fields }">
      <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
    </template>
  </gl-table-lite>
</template>
