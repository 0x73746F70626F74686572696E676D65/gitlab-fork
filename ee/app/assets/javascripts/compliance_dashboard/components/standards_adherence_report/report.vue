<script>
import ComplianceStandardsAdherenceTable from './standards_adherence_table.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTable,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    globalProjectId: {
      type: Number,
      required: false,
      default: null,
    },
  },
};
</script>

<template>
  <compliance-standards-adherence-table
    :group-path="groupPath"
    :global-project-id="globalProjectId"
  />
</template>
