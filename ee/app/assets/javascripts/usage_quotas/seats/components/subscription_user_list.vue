<script>
import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlModal,
  GlModalDirective,
  GlIcon,
  GlPagination,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import dateFormat from '~/lib/dateformat';
import {
  FIELDS,
  AVATAR_SIZE,
  SORT_OPTIONS,
  REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  emailNotVisibleTooltipText,
  filterUsersPlaceholder,
} from 'ee/usage_quotas/seats/constants';
import { s__, __ } from '~/locale';
import SearchAndSortBar from '~/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';
import RemoveBillableMemberModal from './remove_billable_member_modal.vue';
import SubscriptionSeatDetails from './subscription_seat_details.vue';

export default {
  name: 'SubscriptionUserList',
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlModal,
    GlIcon,
    GlPagination,
    GlTable,
    RemoveBillableMemberModal,
    SearchAndSortBar,
    SubscriptionSeatDetails,
  },
  computed: {
    ...mapState([
      'hasError',
      'page',
      'perPage',
      'total',
      'namespaceId',
      'seatUsageExportPath',
      'billableMemberToRemove',
      'search',
    ]),
    ...mapGetters(['tableItems', 'isLoading']),
    currentPage: {
      get() {
        return this.page;
      },
      set(val) {
        this.setCurrentPage(val);
      },
    },
    emptyText() {
      if (this.search?.length < 3) {
        return s__('Billing|Enter at least three characters to search.');
      }
      return s__('Billing|No users to display.');
    },
    isLoaderShown() {
      return this.isLoading || this.hasError;
    },
  },
  methods: {
    ...mapActions([
      'setBillableMemberToRemove',
      'setCurrentPage',
      'setSearchQuery',
      'setSortOption',
    ]),
    formatLastLoginAt(lastLogin) {
      return lastLogin ? dateFormat(lastLogin, 'yyyy-mm-dd HH:MM:ss') : __('Never');
    },
    applyFilter(searchTerm) {
      this.setSearchQuery(searchTerm);
    },
    displayRemoveMemberModal(user) {
      if (user.removable) {
        this.setBillableMemberToRemove(user);
      } else {
        this.$refs.cannotRemoveModal.show();
      }
    },
    isGroupInvite(user) {
      return user.membership_type === 'group_invite';
    },
    isProjectInvite(user) {
      return user.membership_type === 'project_invite';
    },
  },
  i18n: {
    emailNotVisibleTooltipText,
    filterUsersPlaceholder,
  },
  avatarSize: AVATAR_SIZE,
  removeBillableMemberModalId: REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalId: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalTitle: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  cannotRemoveModalText: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  sortOptions: SORT_OPTIONS,
  tableFields: FIELDS,
};
</script>

<template>
  <section>
    <div class="gl-bg-gray-10 gl-p-5 gl-display-flex">
      <search-and-sort-bar
        :namespace="namespaceId"
        :search-input-placeholder="$options.i18n.filterUsersPlaceholder"
        :sort-options="$options.sortOptions"
        initial-sort-by="last_activity_on_desc"
        @onFilter="applyFilter"
        @onSort="setSortOption"
      />
      <gl-button
        v-if="seatUsageExportPath"
        data-testid="export-button"
        :href="seatUsageExportPath"
        class="gl-ml-3"
      >
        {{ s__('Billing|Export list') }}
      </gl-button>
    </div>

    <gl-table
      :items="tableItems"
      :fields="$options.tableFields"
      :busy="isLoaderShown"
      :show-empty="true"
      data-testid="subscription-users"
      :empty-text="emptyText"
    >
      <template #cell(disclosure)="{ item, toggleDetails, detailsShowing }">
        <gl-button
          variant="link"
          class="gl-w-7 gl-h-7"
          :aria-label="s__('Billing|Toggle seat details')"
          :aria-expanded="detailsShowing ? 'true' : 'false'"
          :data-testid="`toggle-seat-usage-details-${item.user.id}`"
          @click="toggleDetails"
        >
          <gl-icon
            :name="detailsShowing ? 'chevron-down' : 'chevron-right'"
            class="gl-text-gray-900"
          />
        </gl-button>
      </template>

      <template #cell(user)="{ item }">
        <div class="gl-display-flex">
          <gl-avatar-link target="blank" :href="item.user.web_url" :alt="item.user.name">
            <gl-avatar-labeled
              :src="item.user.avatar_url"
              :size="$options.avatarSize"
              :label="item.user.name"
              :sub-label="item.user.username"
            >
              <template #meta>
                <gl-badge v-if="isGroupInvite(item.user)" variant="muted">
                  {{ s__('Billing|Group invite') }}
                </gl-badge>
                <gl-badge v-if="isProjectInvite(item.user)" variant="muted">
                  {{ s__('Billing|Project invite') }}
                </gl-badge>
              </template>
            </gl-avatar-labeled>
          </gl-avatar-link>
        </div>
      </template>

      <template #cell(email)="{ item }">
        <div data-testid="email">
          <span v-if="item.email" class="gl-text-gray-900">{{ item.email }}</span>
          <span
            v-else
            v-gl-tooltip
            :title="$options.i18n.emailNotVisibleTooltipText"
            class="gl-italic"
          >
            {{ s__('Billing|Private') }}
          </span>
        </div>
      </template>

      <template #cell(lastActivityTime)="data">
        <span data-testid="last_activity_on">
          {{ data.item.user.last_activity_on ? data.item.user.last_activity_on : __('Never') }}
        </span>
      </template>

      <template #cell(lastLoginAt)="data">
        <span data-testid="last_login_at">
          {{ formatLastLoginAt(data.item.user.last_login_at) }}
        </span>
      </template>

      <template #cell(actions)="data">
        <gl-button
          v-gl-modal="$options.removeBillableMemberModalId"
          category="secondary"
          variant="danger"
          data-testid="remove-user"
          @click="displayRemoveMemberModal(data.item.user)"
        >
          {{ __('Remove user') }}
        </gl-button>
      </template>

      <template #row-details="{ item }">
        <subscription-seat-details :seat-member-id="item.user.id" />
      </template>
    </gl-table>

    <gl-pagination
      v-if="currentPage"
      v-model="currentPage"
      :per-page="perPage"
      :total-items="total"
      align="center"
      class="gl-mt-5"
    />

    <remove-billable-member-modal
      v-if="billableMemberToRemove"
      :modal-id="$options.removeBillableMemberModalId"
    />

    <gl-modal
      ref="cannotRemoveModal"
      :modal-id="$options.cannotRemoveModalId"
      :title="$options.cannotRemoveModalTitle"
      :action-primary="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: __('Okay'),
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      static
    >
      <p>
        {{ $options.cannotRemoveModalText }}
      </p>
    </gl-modal>
  </section>
</template>
<style>
.b-table-has-details > td:first-child {
  border-bottom: none;
}
.b-table-details > td {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
}
</style>
