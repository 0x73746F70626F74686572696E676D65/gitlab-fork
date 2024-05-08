<script>
import groupMostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/group_most_active_runners.query.graphql';
import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import { captureException } from '~/ci/runner/sentry_utils';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { I18N_FETCH_ERROR, JOBS_ROUTE_PATH } from '~/ci/runner/constants';

export default {
  name: 'GroupRunnerActiveList',
  components: {
    RunnerActiveList,
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      activeRunners: [],
    };
  },
  apollo: {
    activeRunners: {
      query: groupMostActiveRunnersQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update(data) {
        const edges = data?.group?.runners?.edges || [];

        return edges
          .map(({ webUrl, node }) => ({
            jobsUrl: this.jobsUrl(webUrl),
            ...node,
          }))
          .filter(({ runningJobCount }) => runningJobCount > 0);
      },
      error(error) {
        createAlert({ message: I18N_FETCH_ERROR });

        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.activeRunners.loading;
    },
  },
  methods: {
    jobsUrl(webUrl) {
      const url = new URL(webUrl);
      url.hash = JOBS_ROUTE_PATH;

      return url.href;
    },
  },
};
</script>
<template>
  <runner-active-list :active-runners="activeRunners" :loading="loading" />
</template>
