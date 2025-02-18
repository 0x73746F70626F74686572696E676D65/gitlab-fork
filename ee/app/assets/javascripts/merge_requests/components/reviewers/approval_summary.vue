<script>
import { n__, sprintf, s__ } from '~/locale';
import { getApprovalRuleNamesLeft } from 'ee/vue_merge_request_widget/mappers';
import { toNounSeriesText } from '~/lib/utils/grammar';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import approvalSummaryQuery from '../../queries/approval_summary.query.graphql';
import approvalSummarySubscription from '../../queries/approval_summary.subscription.graphql';

export default {
  apollo: {
    mergeRequest: {
      query: approvalSummaryQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          iid: this.issuableIid,
        };
      },
      update: (data) => data.project?.mergeRequest,
      subscribeToMore: {
        document: approvalSummarySubscription,
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
            this.mergeRequest = queryResult;
          }
        },
      },
    },
  },
  inject: ['projectPath', 'issuableId', 'issuableIid', 'multipleApprovalRulesAvailable'],
  data() {
    return {
      mergeRequest: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo?.queries?.mergeRequest?.loading || !this.mergeRequest;
    },
    approvalsOptional() {
      return (
        this.mergeRequest.approvalsRequired === 0 && this.mergeRequest.approvedBy.nodes.length === 0
      );
    },
    approvalsLeft() {
      return this.mergeRequest.approvalsLeft || 0;
    },
    rulesLeft() {
      return getApprovalRuleNamesLeft(
        this.multipleApprovalRulesAvailable,
        (this.mergeRequest.approvalState?.rules || []).filter((r) => !r.approved),
      );
    },
    approvalsLeftMessage() {
      if (this.approvalsOptional) {
        return s__('mrWidget|Approval is optional');
      }

      if (this.rulesLeft.length) {
        return sprintf(
          n__(
            'Requires %{count} approval from %{names}.',
            'Requires %{count} approvals from %{names}.',
            this.approvalsLeft,
          ),
          {
            names: toNounSeriesText(this.rulesLeft),
            count: this.approvalsLeft,
          },
          false,
        );
      }

      return n__(
        'Requires %d approval from eligible users.',
        'Requires %d approvals from eligible users.',
        this.approvalsLeft,
      );
    },
  },
};
</script>

<template>
  <div
    v-if="isLoading"
    class="gl-animate-skeleton-loader gl-mt-3 gl-h-4 gl-rounded-base gl-w-full"
  ></div>
  <p v-else-if="mergeRequest" :class="{ 'text-muted': approvalsOptional }" class="gl-mt-3 gl-mb-0">
    {{ approvalsLeftMessage }}
  </p>
</template>
