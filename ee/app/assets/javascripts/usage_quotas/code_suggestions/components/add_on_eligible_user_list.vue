<script>
import {
  GlAlert,
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlFormCheckbox,
  GlSkeletonLoader,
  GlTable,
  GlTooltipDirective,
  GlKeysetPagination,
} from '@gitlab/ui';
import { pick, escape } from 'lodash';
import { __, s__, n__, sprintf } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import {
  ADD_ON_ERROR_DICTIONARY,
  CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE,
  CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE,
  NO_ASSIGNMENTS_FOUND_ERROR_CODE,
  NO_SEATS_AVAILABLE_ERROR_CODE,
  NOT_ENOUGH_SEATS_ERROR_CODE,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  addOnEligibleUserListTableFields,
  ASSIGN_SEATS_BULK_ACTION,
  UNASSIGN_SEATS_BULK_ACTION,
} from 'ee/usage_quotas/code_suggestions/constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import { scrollToElement } from '~/lib/utils/common_utils';
import { isKnownErrorCode } from '~/lib/utils/error_utils';
import CodeSuggestionsAddonAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import AddOnBulkActionConfirmationModal from 'ee/usage_quotas/code_suggestions/components/add_on_bulk_action_confirmation_modal.vue';
import userAddOnAssignmentBulkCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_create.mutation.graphql';
import userAddOnAssignmentBulkRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_remove.mutation.graphql';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';
import { addSeatsText } from 'ee/usage_quotas/seats/constants';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';

export default {
  name: 'AddOnEligibleUserList',
  links: {
    sales: `${PROMO_URL}/solutions/code-suggestions/sales/`,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  components: {
    AddOnBulkActionConfirmationModal,
    CodeSuggestionsAddonAssignment,
    ErrorAlert,
    GlAlert,
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlFormCheckbox,
    GlKeysetPagination,
    GlSkeletonLoader,
    GlTable,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    addDuoProHref: {},
    groupId: {},
    isBulkAddOnAssignmentEnabled: { default: false },
    subscriptionName: { default: null },
  },
  props: {
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    users: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    pageInfo: {
      type: Object,
      required: false,
      default: () => {},
    },
    search: {
      type: String,
      required: false,
      default: '',
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (val) => [DUO_PRO, DUO_ENTERPRISE].includes(val),
    },
  },
  i18n: {
    addSeatsText,
    contactSalesText: __('Contact sales'),
  },
  data() {
    return {
      error: undefined,
      selectedUsers: [],
      bulkAction: undefined,
      successMessage: undefined,
      isBulkActionInProgress: false,
      isConfirmationModalVisible: false,
    };
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  assignSeatsBulkAction: ASSIGN_SEATS_BULK_ACTION,
  unassignSeatsBulkAction: UNASSIGN_SEATS_BULK_ACTION,
  avatarSize: 32,
  apollo: {
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return this.subscriptionPermissionsVariables;
      },
      skip() {
        return this.hasNoRequestInformation;
      },
      update: (data) => ({
        canAddDuoProSeats: data.subscription?.canAddDuoProSeats,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error(error) {
        this.forwardException(Object.assign(error, { cause: ADD_ON_PURCHASE_FETCH_ERROR_CODE }));
      },
    },
  },
  computed: {
    hasMaxRoleField() {
      return this.tableItems?.some(({ maxRole }) => maxRole);
    },
    isFilteringEnabled() {
      return this.glFeatures.enableAddOnUsersFiltering;
    },
    showPagination() {
      if (this.isLoading || !this.pageInfo) {
        return false;
      }
      const { hasNextPage, hasPreviousPage } = this.pageInfo;
      return hasNextPage || hasPreviousPage;
    },
    emptyText() {
      if (this.search?.length < 3) {
        return s__('Billing|Enter at least three characters to search.');
      }
      return s__('Billing|No users to display.');
    },
    duoPlan() {
      return this.duoTier === 'enterprise' ? 'duoEnterpriseAddon' : 'codeSuggestionsAddon';
    },
    tableFieldsConfiguration() {
      let fieldConfig = ['user', this.duoPlan, 'emailWide', 'lastActivityTimeWide'];

      if (this.isFilteringEnabled && this.hasMaxRoleField) {
        fieldConfig = ['user', this.duoPlan, 'email', 'maxRole', 'lastActivityTime'];
      }

      if (this.isBulkAddOnAssignmentEnabled) {
        fieldConfig = ['checkbox', ...fieldConfig];
      }

      return fieldConfig;
    },
    tableFields() {
      return Object.values(pick(addOnEligibleUserListTableFields, this.tableFieldsConfiguration));
    },
    tableItems() {
      return this.users.map((node) => ({
        ...node,
        usernameWithHandle: `@${node?.username}`,
        addOnAssignments: node?.addOnAssignments?.nodes,
      }));
    },
    isSelectAllUsersChecked() {
      return !this.isLoading && this.users.length === this.selectedUsers.length;
    },
    isSelectAllUsersIndeterminate() {
      return this.isAnyUserSelected && !this.isSelectAllUsersChecked;
    },
    isAnyUserSelected() {
      return Boolean(this.selectedUsers.length);
    },
    pluralisedSelectedUsers() {
      return sprintf(
        n__(
          'Billing|%{value} user selected',
          'Billing|%{value} users selected',
          this.selectedUsers.length,
        ),
        { value: `<strong>${escape(this.selectedUsers.length)}</strong>` },
        false,
      );
    },
    isBulkActionToAssignSeats() {
      return this.bulkAction === ASSIGN_SEATS_BULK_ACTION;
    },
    errorAlertPrimaryButtonText() {
      const isErrorKnown =
        this.error === NO_SEATS_AVAILABLE_ERROR_CODE || this.error === NOT_ENOUGH_SEATS_ERROR_CODE;

      if (this.hideAddSeatsButton || !isErrorKnown) {
        return '';
      }

      return this.$options.i18n.addSeatsText;
    },
    hideAddSeatsButton() {
      return !this.subscriptionPermissions?.canAddDuoProSeats && this.hasLimitedAccess;
    },
    subscriptionPermissionsVariables() {
      return this.groupId
        ? { namespaceId: this.parsedGroupId }
        : { subscriptionName: this.subscriptionName };
    },
    hasLimitedAccess() {
      return LIMITED_ACCESS_KEYS.includes(this.permissionReason);
    },
    permissionReason() {
      return this.subscriptionPermissions?.reason;
    },
    hasNoRequestInformation() {
      return !(this.groupId || this.subscriptionName);
    },
    parsedGroupId() {
      return parseInt(this.groupId, 10);
    },
  },
  methods: {
    nextPage() {
      // Retaining user selection on page navigation will be carried out in
      // https://gitlab.com/gitlab-org/gitlab/-/issues/443401
      this.unselectAllUsers();
      this.$emit('next', this.pageInfo.endCursor);
    },
    prevPage() {
      // Retaining user selection on page navigation will be carried out in
      // https://gitlab.com/gitlab-org/gitlab/-/issues/443401
      this.unselectAllUsers();
      this.$emit('prev', this.pageInfo.startCursor);
    },
    handleError(error) {
      this.error = error;
      this.scrollToTop();
    },
    scrollToTop() {
      scrollToElement(this.$el);
    },
    isUserSelected(item) {
      return this.selectedUsers.includes(item.id);
    },
    handleUserSelection(user, value) {
      if (value) {
        this.selectedUsers.push(user.id);
      } else {
        this.selectedUsers = this.selectedUsers.filter((id) => id !== user.id);
      }
    },
    handleSelectAllUsers(value) {
      if (value) {
        this.selectedUsers = this.users.map((user) => user.id);
      } else {
        this.unselectAllUsers();
      }
    },
    unselectAllUsers() {
      this.selectedUsers = [];
    },
    showConfirmationModal(bulkAction) {
      this.isConfirmationModalVisible = true;
      this.bulkAction = bulkAction;
    },
    handleCancelBulkAction() {
      this.isConfirmationModalVisible = false;
      this.bulkAction = undefined;
    },
    clearAlerts() {
      this.error = undefined;
      this.successMessage = undefined;
    },
    async assignSeats() {
      this.clearAlerts();
      this.isBulkActionInProgress = true;

      try {
        const {
          data: { userAddOnAssignmentBulkCreate },
        } = await this.$apollo.mutate({
          mutation: userAddOnAssignmentBulkCreateMutation,
          variables: {
            userIds: this.selectedUsers,
            addOnPurchaseId: this.addOnPurchaseId,
          },
        });

        const errors = userAddOnAssignmentBulkCreate?.errors || [];

        if (errors.length) {
          this.handleBulkActionError(errors[0]);
        } else {
          this.handleBulkActionSuccess();
        }
      } catch (e) {
        this.handleBulkActionError(e);
        Sentry.captureException(e);
      } finally {
        this.resetBulkAction();
      }
    },
    async unassignSeats() {
      this.clearAlerts();
      this.isBulkActionInProgress = true;

      try {
        const {
          data: { userAddOnAssignmentBulkRemove },
        } = await this.$apollo.mutate({
          mutation: userAddOnAssignmentBulkRemoveMutation,
          variables: {
            userIds: this.selectedUsers,
            addOnPurchaseId: this.addOnPurchaseId,
          },
        });

        const errors = userAddOnAssignmentBulkRemove?.errors || [];

        if (errors.length) {
          const error = errors[0];
          if (error === NO_ASSIGNMENTS_FOUND_ERROR_CODE) {
            // NO_ASSIGNMENTS_FOUND is returned when none of the users provided
            // have add-on assignment - we consider this a success on the UI
            // as customer is trying to unassign add-on to users who already have
            // no assignment therefore not raising an error for this scenario
            this.handleBulkActionSuccess();
            return;
          }
          this.handleBulkActionError(error);
        } else {
          this.handleBulkActionSuccess();
        }
      } catch (e) {
        this.handleBulkActionError(e);
        Sentry.captureException(e);
      } finally {
        this.resetBulkAction();
      }
    },
    handleBulkActionSuccess() {
      if (this.isBulkActionToAssignSeats) {
        this.successMessage = n__(
          'Billing|%d user has been successfully assigned a seat.',
          'Billing|%d users have been successfully assigned a seat.',
          this.selectedUsers.length,
        );
      } else {
        this.successMessage = n__(
          'Billing|%d user has been successfully unassigned a seat.',
          'Billing|%d users have been successfully unassigned a seat.',
          this.selectedUsers.length,
        );
      }
      this.unselectAllUsers();
    },
    handleBulkActionError(error) {
      let bulkActionError;

      if (isKnownErrorCode(error, ADD_ON_ERROR_DICTIONARY)) {
        bulkActionError = error;
      } else if (this.isBulkActionToAssignSeats) {
        bulkActionError = CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE;
      } else {
        bulkActionError = CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE;
      }

      this.handleError(bulkActionError);
    },
    resetBulkAction() {
      this.bulkAction = undefined;
      this.isBulkActionInProgress = false;
      this.isConfirmationModalVisible = false;
    },
    forwardException(error) {
      this.$emit('error', error);

      Sentry.captureException(error, { tags: { vue_component: this.$options.name } });
    },
  },
};
</script>

<template>
  <section>
    <slot name="search-and-sort-bar"> </slot>
    <slot name="error-alert"></slot>
    <error-alert
      v-if="error"
      data-testid="error-alert"
      :error="error"
      :error-dictionary="$options.addOnErrorDictionary"
      :dismissible="true"
      :primary-button-link="addDuoProHref"
      :primary-button-text="errorAlertPrimaryButtonText"
      :secondary-button-link="$options.links.sales"
      :secondary-button-text="$options.i18n.contactSalesText"
      @dismiss="error = undefined"
    />
    <gl-alert
      v-if="successMessage"
      data-testid="success-alert"
      variant="success"
      :dismissible="true"
      @dismiss="successMessage = undefined"
    >
      {{ successMessage }}
    </gl-alert>
    <div
      v-if="isAnyUserSelected"
      class="gl-display-flex gl-mt-5 gl-bg-gray-10 gl-p-5 gl-align-items-center gl-justify-content-space-between"
    >
      <span v-safe-html="pluralisedSelectedUsers" data-testid="selected-users-summary"></span>
      <div class="gl-display-flex gl-gap-3">
        <gl-button
          data-testid="unassign-seats-button"
          variant="danger"
          category="secondary"
          @click="showConfirmationModal($options.unassignSeatsBulkAction)"
          >{{ s__('Billing|Remove seat') }}</gl-button
        >
        <gl-button
          data-testid="assign-seats-button"
          variant="confirm"
          category="primary"
          @click="showConfirmationModal($options.assignSeatsBulkAction)"
          >{{ s__('Billing|Assign seat') }}</gl-button
        >
      </div>
    </div>
    <gl-table
      :items="tableItems"
      :fields="tableFields"
      :busy="isLoading"
      :show-empty="true"
      :empty-text="emptyText"
      primary-key="id"
      data-testid="add-on-eligible-users-table"
    >
      <template #table-busy>
        <div class="-gl-ml-4 gl-pt-3">
          <gl-skeleton-loader>
            <rect x="0" y="0" width="60" height="3" rx="1" />
            <rect x="126" y="0" width="60" height="3" rx="1" />
            <rect x="207" y="0" width="60" height="3" rx="1" />
            <rect x="338" y="0" width="60" height="3" rx="1" />
          </gl-skeleton-loader>
        </div>
      </template>
      <template #head(checkbox)>
        <gl-form-checkbox
          v-if="isBulkAddOnAssignmentEnabled"
          class="gl-min-h-5"
          :checked="isSelectAllUsersChecked"
          :indeterminate="isSelectAllUsersIndeterminate"
          data-testid="select-all-users"
          @change="handleSelectAllUsers"
        />
      </template>
      <template #cell(checkbox)="{ item }">
        <gl-form-checkbox
          v-if="isBulkAddOnAssignmentEnabled"
          class="gl-min-h-5"
          :checked="isUserSelected(item)"
          @change="handleUserSelection(item, $event)"
        />
      </template>
      <template #cell(user)="{ item }">
        <slot name="user-cell" :item="item">
          <div class="gl-display-flex">
            <gl-avatar-link target="_blank" :href="item.webUrl" :alt="item.name">
              <gl-avatar-labeled
                :src="item.avatarUrl"
                :size="$options.avatarSize"
                :label="item.name"
                :sub-label="item.usernameWithHandle"
              />
            </gl-avatar-link>
          </div>
        </slot>
      </template>
      <template #cell(email)="{ item }">
        <div data-testid="email">
          <span v-if="item.publicEmail" class="gl-text-gray-900">{{ item.publicEmail }}</span>
          <span
            v-else
            v-gl-tooltip
            :title="s__('Billing|An email address is only visible for users with public emails.')"
            class="gl-italic"
          >
            {{ s__('Billing|Private') }}
          </span>
        </div>
      </template>
      <template #cell(codeSuggestionsAddon)="{ item }">
        <code-suggestions-addon-assignment
          :user-id="item.id"
          :add-on-assignments="item.addOnAssignments"
          :add-on-purchase-id="addOnPurchaseId"
          :duo-tier="duoTier"
          @handleError="handleError"
          @clearError="clearAlerts"
        />
      </template>
      <template #cell(maxRole)="{ item }">
        <gl-badge v-if="item.maxRole" data-testid="max-role">{{ item.maxRole }}</gl-badge>
      </template>
      <template #cell(lastActivityTime)="data">
        <span data-testid="last-activity-on">
          {{ data.item.lastActivityOn ? data.item.lastActivityOn : __('Never') }}
        </span>
      </template>
    </gl-table>
    <div v-if="showPagination" class="gl-display-flex gl-justify-content-center gl-mt-5">
      <gl-keyset-pagination v-bind="pageInfo" @prev="prevPage" @next="nextPage" />
    </div>

    <add-on-bulk-action-confirmation-modal
      v-if="isConfirmationModalVisible"
      :bulk-action="bulkAction"
      :user-count="selectedUsers.length"
      :is-bulk-action-in-progress="isBulkActionInProgress"
      @confirm-seat-assignment="assignSeats"
      @confirm-seat-unassignment="unassignSeats"
      @cancel="handleCancelBulkAction"
    />
  </section>
</template>
