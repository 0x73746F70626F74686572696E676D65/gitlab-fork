<script>
import { GlToggle } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import {
  ADD_ON_CODE_SUGGESTIONS,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE,
  DUO_ENTERPRISE_TITLE,
  DUO_PRO,
} from 'ee/usage_quotas/code_suggestions/constants';
import {
  CANNOT_ASSIGN_ADDON_ERROR_CODE,
  CANNOT_UNASSIGN_ADDON_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import { isKnownErrorCode } from '~/lib/utils/error_utils';
import userAddOnAssignmentCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_create.mutation.graphql';
import userAddOnAssignmentRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_remove.mutation.graphql';

export default {
  name: 'CodeSuggestionsAddonAssignment',
  components: {
    GlToggle,
  },
  props: {
    userId: {
      type: String,
      required: true,
    },
    addOnAssignments: {
      type: Array,
      required: false,
      default: () => [],
    },
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (value) => [DUO_PRO, DUO_ENTERPRISE].includes(value),
    },
  },
  data() {
    return {
      isLoading: false,
      toggleId: `toggle-${this.userId}`,
    };
  },
  computed: {
    isAssigned() {
      return Boolean(
        this.addOnAssignments?.find(
          (assignment) => assignment.addOnPurchase?.name === ADD_ON_CODE_SUGGESTIONS,
        ),
      );
    },
    addOnAssignmentQueryVariables() {
      return {
        userId: this.userId,
        addOnPurchaseId: this.addOnPurchaseId,
      };
    },
    toggleLabel() {
      return sprintf(s__('CodeSuggestions|%{addOnName} status'), {
        addOnName: this.duoTier === DUO_ENTERPRISE ? DUO_ENTERPRISE_TITLE : CODE_SUGGESTIONS_TITLE,
      });
    },
  },
  methods: {
    async onToggle() {
      this.isLoading = true;
      this.$emit('clearAddOnAssignmentError');

      try {
        const response = this.isAssigned ? await this.unassignAddOn() : await this.assignAddOn();

        // Null response here means it didn't error but we're trying unassign an already unassigned user
        // https://gitlab.com/gitlab-org/gitlab/-/issues/426175 should take care of returning a response
        // instead of null value similar to how assignment mutation works when assigning an already assigned user
        if (!response) {
          return;
        }

        const errors = response.errors || [];
        if (errors.length) {
          this.handleError(errors[0]);
        }
      } catch (e) {
        this.handleError(e);
        Sentry.captureException(e);
      } finally {
        this.isLoading = false;
      }
    },
    handleError(error) {
      let errorCode = error;
      if (!isKnownErrorCode(error, ADD_ON_ERROR_DICTIONARY)) {
        errorCode = this.isAssigned
          ? CANNOT_UNASSIGN_ADDON_ERROR_CODE
          : CANNOT_ASSIGN_ADDON_ERROR_CODE;
      }
      this.$emit('handleAddOnAssignmentError', errorCode);
    },
    async assignAddOn() {
      const {
        data: { userAddOnAssignmentCreate },
      } = await this.$apollo.mutate({
        mutation: userAddOnAssignmentCreateMutation,
        variables: this.addOnAssignmentQueryVariables,
      });
      return userAddOnAssignmentCreate;
    },
    async unassignAddOn() {
      const {
        data: { userAddOnAssignmentRemove },
      } = await this.$apollo.mutate({
        mutation: userAddOnAssignmentRemoveMutation,
        variables: this.addOnAssignmentQueryVariables,
      });
      return userAddOnAssignmentRemove;
    },
  },
};
</script>
<template>
  <div>
    <gl-toggle
      :id="toggleId"
      :value="isAssigned"
      :label="toggleLabel"
      :is-loading="isLoading"
      class="gl-display-inline-block gl-align-middle"
      label-position="hidden"
      @change="onToggle"
    />
  </div>
</template>
