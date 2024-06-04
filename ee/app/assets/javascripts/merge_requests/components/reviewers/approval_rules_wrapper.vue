<script>
import { __ } from '~/locale';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import approvalRulesQuery from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.query.graphql';
import approvalRulesSubscription from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.subscription.graphql';
import ApprovalRules from './approval_rules.vue';

export default {
  apollo: {
    approvalRules: {
      query: approvalRulesQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          iid: this.issuableIid,
        };
      },
      skip() {
        return !this.multipleApprovalRulesAvailable;
      },
      update: (data) => data.project?.mergeRequest?.approvalState?.rules || [],
      subscribeToMore: {
        document: approvalRulesSubscription,
        variables() {
          return {
            issuableId: convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.issuableId),
          };
        },
        updateQuery(
          _,
          {
            subscriptionData: {
              data: { mergeRequestApprovalStateUpdated: queryResult },
            },
          },
        ) {
          if (queryResult) {
            this.approvalRules = queryResult.approvalState?.rules || [];
          }
        },
      },
    },
  },
  components: {
    ApprovalRules,
  },
  inject: ['projectPath', 'issuableIid', 'issuableId', 'multipleApprovalRulesAvailable'],
  props: {
    reviewers: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      approvalRules: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries.approvalRules.loading;
    },
    mappedApprovalRules() {
      const codeOwners = this.approvalRules.filter(({ type }) => type === 'CODE_OWNER');
      const regular = this.approvalRules.filter(
        ({ type }) => type === 'REGULAR' || type === 'ANY_APPROVER',
      );

      return [
        {
          key: 'code_owner',
          label: __('Code Owners'),
          rules: codeOwners,
        },
        {
          key: 'regular',
          label: __('Approval Rules'),
          rules: regular,
        },
      ].filter(({ rules }) => rules.length);
    },
  },
};
</script>

<template>
  <div v-if="isLoading">
    <div class="gl-animate-skeleton-loader gl-h-4 gl-rounded-base gl-mb-3 gl-max-w-30!"></div>
    <div class="gl-animate-skeleton-loader gl-h-4 gl-rounded-base gl-mb-3 gl-max-w-30!"></div>
    <div class="gl-animate-skeleton-loader gl-h-4 gl-rounded-base gl-mb-3 gl-max-w-30!"></div>
    <div class="gl-animate-skeleton-loader gl-h-4 gl-rounded-base gl-mb-3 gl-max-w-30!"></div>
  </div>
  <div v-else>
    <approval-rules
      v-for="group in mappedApprovalRules"
      :key="group.key"
      :reviewers="reviewers"
      :group="group"
    />
  </div>
</template>
