<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import getAddOnPurchaseQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchase.query.graphql';
import {
  ADD_ON_CODE_SUGGESTIONS,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE,
  DUO_ENTERPRISE_TITLE,
  DUO_PRO,
} from 'ee/usage_quotas/code_suggestions/constants';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import CodeSuggestionsInfoCard from './code_suggestions_info_card.vue';
import CodeSuggestionsIntro from './code_suggestions_intro.vue';
import CodeSuggestionsStatisticsCard from './code_suggestions_usage_statistics_card.vue';

export default {
  name: 'CodeSuggestionsUsage',
  components: {
    ErrorAlert,
    SaasAddOnEligibleUserList,
    SelfManagedAddOnEligibleUserList,
    CodeSuggestionsInfoCard,
    CodeSuggestionsIntro,
    CodeSuggestionsStatisticsCard,
    GlSkeletonLoader,
  },
  inject: { isSaaS: {}, groupId: { default: null } },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  data() {
    return {
      addOnPurchase: undefined,
      addOnPurchaseFetchError: undefined,
    };
  },
  computed: {
    queryVariables() {
      return {
        namespaceId: this.groupGraphQLId,
        addOnType: ADD_ON_CODE_SUGGESTIONS,
      };
    },
    groupGraphQLId() {
      return this.groupId ? convertToGraphQLId(TYPENAME_GROUP, this.groupId) : null;
    },
    totalValue() {
      return this.addOnPurchase?.purchasedQuantity ?? 0;
    },
    usageValue() {
      return this.addOnPurchase?.assignedQuantity ?? 0;
    },
    hasCodeSuggestions() {
      return this.totalValue !== null && this.totalValue > 0;
    },
    isLoading() {
      return this.$apollo.queries.addOnPurchase.loading;
    },
    duoTier() {
      return this.addOnPurchase?.name === 'DUO_ENTERPRISE' ? DUO_ENTERPRISE : DUO_PRO;
    },
    showTitleAndSubtitle() {
      if (this.isSaaS) {
        return false;
      }
      return !this.isLoading && (this.hasCodeSuggestions || this.addOnPurchaseFetchError);
    },
    codeSuggestionsSubtitle() {
      return sprintf(
        s__('CodeSuggestions|Manage seat assignments for %{addOnName} across your instance.'),
        {
          addOnName: this.codeSuggestionsFriendlyName,
        },
      );
    },
    codeSuggestionsTitle() {
      return this.codeSuggestionsFriendlyName;
    },
    codeSuggestionsFriendlyName() {
      return this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE;
    },
  },
  apollo: {
    addOnPurchase: {
      query: getAddOnPurchaseQuery,
      variables() {
        return this.queryVariables;
      },
      update({ addOnPurchase }) {
        return addOnPurchase;
      },
      error(error) {
        const errorWithCause = Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE });
        this.handleAddOnPurchaseFetchError(errorWithCause);
        this.reportError(error);
      },
    },
  },
  methods: {
    handleAddOnPurchaseFetchError(error) {
      this.addOnPurchaseFetchError = error;
    },
    reportError(error) {
      Sentry.captureException(error, {
        tags: {
          vue_component: this.$options.name,
        },
      });
    },
  },
};
</script>

<template>
  <section>
    <section
      v-if="isLoading"
      class="gl-display-grid gl-md-grid-template-columns-2 gl-gap-5 gl-mt-5"
    >
      <div class="gl-bg-white gl-border gl-p-5 gl-rounded-base">
        <gl-skeleton-loader :height="64">
          <rect width="140" height="30" x="5" y="0" rx="4" />
          <rect width="240" height="10" x="5" y="40" rx="4" />
          <rect width="340" height="10" x="5" y="54" rx="4" />
        </gl-skeleton-loader>
      </div>

      <div class="gl-bg-white gl-border gl-p-5 gl-rounded-base">
        <gl-skeleton-loader :height="64">
          <rect width="240" height="10" x="5" y="0" rx="4" />
          <rect width="340" height="10" x="5" y="14" rx="4" />
          <rect width="220" height="8" x="5" y="40" rx="4" />
          <rect width="220" height="8" x="5" y="54" rx="4" />
        </gl-skeleton-loader>
      </div>
    </section>
    <template v-else>
      <section v-if="showTitleAndSubtitle">
        <h1 data-testid="code-suggestions-title" class="page-title gl-font-size-h-display">
          {{ codeSuggestionsTitle }}
        </h1>

        <p data-testid="code-suggestions-subtitle">
          {{ codeSuggestionsSubtitle }}
        </p>
      </section>
      <section v-if="hasCodeSuggestions">
        <section
          class="gl-display-grid gl-md-grid-template-columns-2 gl-gap-5 gl-bg-gray-10 gl-p-5"
        >
          <code-suggestions-statistics-card
            :total-value="totalValue"
            :usage-value="usageValue"
            :duo-tier="duoTier"
          />
          <code-suggestions-info-card
            :group-id="groupId"
            :duo-tier="duoTier"
            @error="handleAddOnPurchaseFetchError"
          />
        </section>
        <saas-add-on-eligible-user-list
          v-if="isSaaS"
          :add-on-purchase-id="addOnPurchase.id"
          :duo-tier="duoTier"
        />
        <self-managed-add-on-eligible-user-list
          v-else
          :add-on-purchase-id="addOnPurchase.id"
          :duo-tier="duoTier"
        />
      </section>
      <error-alert
        v-else-if="addOnPurchaseFetchError"
        data-testid="add-on-purchase-fetch-error"
        :error="addOnPurchaseFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        class="gl-mt-5"
      />
      <code-suggestions-intro v-else />
    </template>
  </section>
</template>
