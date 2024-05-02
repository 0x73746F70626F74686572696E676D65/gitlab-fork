<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlButton } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { s__ } from '~/locale';
import {
  WORKSPACES_LIST_PAGE_SIZE,
  ROUTES,
  WORKSPACES_LIST_POLL_INTERVAL,
  I18N_LOADING_WORKSPACES_FAILED,
} from '../constants';
import userWorkspacesListQuery from '../../common/graphql/queries/user_workspaces_list.query.graphql';
import WorkspacesList from '../../common/components/workspaces_list/workspaces_list.vue';
import {
  fetchProjectsDetails,
  populateWorkspacesWithProjectDetails,
} from '../../common/services/utils';

export const i18n = {
  newWorkspaceButton: s__('Workspaces|New workspace'),
  loadingWorkspacesFailed: I18N_LOADING_WORKSPACES_FAILED,
};

export default {
  components: {
    GlButton,
    WorkspacesList,
  },
  apollo: {
    workspaces: {
      query: userWorkspacesListQuery,
      pollInterval: WORKSPACES_LIST_POLL_INTERVAL,
      variables() {
        return {
          ...this.paginationVariables,
        };
      },
      update(data) {
        return data.currentUser.workspaces?.nodes || [];
      },
      error(err) {
        logError(err);
      },
      async result({ data, error }) {
        if (error) {
          this.error = i18n.loadingWorkspacesFailed;
          return;
        }
        const workspaces = data.currentUser.workspaces.nodes;
        const result = await fetchProjectsDetails(this.$apollo, workspaces);

        if (result.error) {
          this.error = i18n.loadingWorkspacesFailed;
          this.workspaces = [];
          logError(result.error);
          return;
        }

        this.workspaces = populateWorkspacesWithProjectDetails(workspaces, result.projects);
        this.pageInfo = data.currentUser.workspaces.pageInfo;
      },
    },
  },
  data() {
    return {
      workspaces: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      paginationVariables: {
        first: WORKSPACES_LIST_PAGE_SIZE,
        after: null,
        before: null,
      },
      error: '',
    };
  },
  computed: {
    isEmpty() {
      return !this.workspaces.length && !this.isLoading;
    },
    isLoading() {
      return this.$apollo.loading;
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    onUpdateFailed({ error }) {
      this.error = error;
    },
    onPaginationInput(paginationVariables) {
      this.paginationVariables = paginationVariables;
    },
  },
  i18n,
  ROUTES,
  WORKSPACES_LIST_PAGE_SIZE,
};
</script>
<template>
  <workspaces-list
    :workspaces="workspaces"
    :error="error"
    :page-info="pageInfo"
    :is-loading="isLoading"
    :new-workspace-path="$options.ROUTES.new"
    :page-size="$options.WORKSPACES_LIST_PAGE_SIZE"
    @error="onError"
    @page="onPaginationInput"
  >
    <template v-if="!isEmpty" #header>
      <gl-button variant="confirm" :to="$options.ROUTES.new" data-testid="list-new-workspace-button"
        >{{ $options.i18n.newWorkspaceButton }}
      </gl-button>
    </template>
  </workspaces-list>
</template>
