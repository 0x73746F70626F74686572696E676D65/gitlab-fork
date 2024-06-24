<script>
import IssuesDashboardApp from '~/issues/dashboard/components/issues_dashboard_app.vue';
import { TYPE_TOKEN_KEY_RESULT_OPTION, TYPE_TOKEN_OBJECTIVE_OPTION } from '~/issues/list/constants';

export default {
  components: {
    IssuesDashboardApp,
  },
  inject: ['hasOkrsFeature'],
  computed: {
    typeTokenOptions() {
      const typeTokens = [];
      if (this.hasOkrsFeature) {
        typeTokens.push(TYPE_TOKEN_OBJECTIVE_OPTION, TYPE_TOKEN_KEY_RESULT_OPTION);
      }
      return typeTokens;
    },
  },
};
</script>

<template>
  <issues-dashboard-app :ee-type-token-options="typeTokenOptions" />
</template>
