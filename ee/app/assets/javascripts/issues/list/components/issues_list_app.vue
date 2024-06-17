<script>
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  OPERATORS_IS_NOT,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_WEIGHT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_EPIC,
  TOKEN_TITLE_ITERATION,
  TOKEN_TITLE_WEIGHT,
  TOKEN_TITLE_HEALTH,
  TOKEN_TYPE_HEALTH,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import {
  TYPE_TOKEN_EPIC_OPTION,
  TYPE_TOKEN_OBJECTIVE_OPTION,
  TYPE_TOKEN_KEY_RESULT_OPTION,
} from '~/issues/list/constants';
import {
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
} from '~/work_items/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_EPIC } from '~/graphql_shared/constants';
import searchIterationsQuery from '../queries/search_iterations.query.graphql';

import NewIssueDropdown from './new_issue_dropdown.vue';

const EpicToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue');
const IterationToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue');
const WeightToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue');
const HealthToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue');
const ChildEpicIssueIndicator = () =>
  import('ee/issuable/child_epic_issue_indicator/components/child_epic_issue_indicator.vue');

export default {
  name: 'IssuesListAppEE',
  components: {
    IssuesListApp: () => import('~/issues/list/components/issues_list_app.vue'),
    NewIssueDropdown,
    ChildEpicIssueIndicator,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'fullPath',
    'groupPath',
    'hasEpicsFeature',
    'hasIssueWeightsFeature',
    'hasIterationsFeature',
    'hasIssuableHealthStatusFeature',
    'hasOkrsFeature',
    'isProject',
  ],
  computed: {
    namespace() {
      return this.isProject ? WORKSPACE_PROJECT : WORKSPACE_GROUP;
    },
    workItemTypes() {
      const types = [];
      if (this.hasEpicsFeature && !this.isProject) {
        types.push(WORK_ITEM_TYPE_ENUM_EPIC);
      }
      if (this.isOkrsEnabled) {
        types.push(WORK_ITEM_TYPE_ENUM_OBJECTIVE, WORK_ITEM_TYPE_ENUM_KEY_RESULT);
      }
      return types;
    },
    typeTokenOptions() {
      const typeTokens = [];
      if (this.hasEpicsFeature && !this.isProject && this.glFeatures.workItemsAlpha) {
        typeTokens.push(TYPE_TOKEN_EPIC_OPTION);
      }
      if (this.isOkrsEnabled) {
        typeTokens.push(TYPE_TOKEN_OBJECTIVE_OPTION, TYPE_TOKEN_KEY_RESULT_OPTION);
      }
      return typeTokens;
    },
    isOkrsEnabled() {
      return this.hasOkrsFeature && this.glFeatures.okrsMvc;
    },
    searchTokens() {
      const tokens = [];

      if (this.hasIterationsFeature) {
        tokens.push({
          type: TOKEN_TYPE_ITERATION,
          title: TOKEN_TITLE_ITERATION,
          icon: 'iteration',
          token: IterationToken,
          fetchIterations: this.fetchIterations,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-iteration`,
          fullPath: this.fullPath,
          isProject: this.isProject,
        });
      }

      if (this.groupPath) {
        tokens.push({
          type: TOKEN_TYPE_EPIC,
          title: TOKEN_TITLE_EPIC,
          icon: 'epic',
          token: EpicToken,
          unique: true,
          symbol: '&',
          idProperty: 'id',
          useIdValue: true,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-epic`,
          fullPath: this.groupPath,
        });
      }

      if (this.hasIssueWeightsFeature) {
        tokens.push({
          type: TOKEN_TYPE_WEIGHT,
          title: TOKEN_TITLE_WEIGHT,
          icon: 'weight',
          token: WeightToken,
          unique: true,
        });
      }

      if (this.hasIssuableHealthStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_HEALTH,
          title: TOKEN_TITLE_HEALTH,
          icon: 'status-health',
          operators: OPERATORS_IS_NOT,
          token: HealthToken,
          unique: false,
        });
      }

      return tokens;
    },
  },
  methods: {
    refetchIssuables() {
      this.$refs.issuesListApp.$apollo.queries.issues.refetch();
      this.$refs.issuesListApp.$apollo.queries.issuesCounts.refetch();
    },
    fetchIterations(search) {
      const id = Number(search);
      const variables =
        !search || Number.isNaN(id)
          ? { fullPath: this.fullPath, search, isProject: this.isProject }
          : { fullPath: this.fullPath, id, isProject: this.isProject };

      variables.state = 'all';

      return this.$apollo
        .query({
          query: searchIterationsQuery,
          variables,
        })
        .then(({ data }) => data[this.namespace]?.iterations.nodes);
    },
    hasFilteredEpicId(apiFilterParams) {
      return Boolean(apiFilterParams.epicId);
    },
    getFilteredEpicId(apiFilterParams) {
      const { epicId } = apiFilterParams;

      if (!epicId) {
        return '';
      }

      return convertToGraphQLId(TYPENAME_EPIC, parseInt(epicId, 10));
    },
  },
};
</script>

<template>
  <issues-list-app
    ref="issuesListApp"
    class="js-issues-list-app"
    :ee-work-item-types="workItemTypes"
    :ee-type-token-options="typeTokenOptions"
    :ee-search-tokens="searchTokens"
  >
    <template v-if="isOkrsEnabled" #new-issuable-button>
      <new-issue-dropdown @workItemCreated="refetchIssuables" />
    </template>
    <template #title-icons="{ issuable, apiFilterParams }">
      <child-epic-issue-indicator
        v-if="hasFilteredEpicId(apiFilterParams)"
        class="gl-ml-2"
        :filtered-epic-id="getFilteredEpicId(apiFilterParams)"
        :issuable="issuable"
      />
    </template>
  </issues-list-app>
</template>
