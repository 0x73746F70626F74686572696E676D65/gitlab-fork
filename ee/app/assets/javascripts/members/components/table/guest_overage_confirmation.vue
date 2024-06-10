<script>
import { GlModal, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import { isNil } from 'lodash';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getBillableUserCountChanges from 'ee/invite_members/graphql/queries/billable_users_count.query.graphql';
import { ACCESS_LEVEL_LABELS } from '~/access_level/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { n__, s__, __ } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';

export default {
  components: { GlModal, GlSprintf, GlLink, GlIcon },
  mixins: [glFeatureFlagsMixin()],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: '',
    },
    member: {
      type: Object,
      required: false,
      default: null,
    },
    role: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      seatsInSubscription: null,
      newBillableUserCount: null,
      groupName: null,
      isModalVisible: false,
    };
  },
  computed: {
    reconciliationDocsPath() {
      return helpPagePath('subscriptions/quarterly_reconciliation');
    },
    currentSeatCountMessage() {
      return n__(
        'MembersOverage|Your subscription includes %d seat.',
        'MembersOverage|Your subscription includes %d seats.',
        this.seatsInSubscription || 0,
      );
    },
    newSeatCountMessage() {
      return n__(
        'MembersOverage|If you continue, the %{groupName} group will have %{seatCount} seat in use and will be billed for the overage.',
        'MembersOverage|If you continue, the %{groupName} group will have %{seatCount} seats in use and will be billed for the overage.',
        this.newBillableUserCount || 0,
      );
    },
    shouldSkipConfirmationCheck() {
      return (
        // Skip if feature flag is off.
        !this.glFeatures.showOverageOnRolePromotion ||
        // Skip if there's no group path (e.g. a personal project), the subscription data is only available for groups.
        !this.groupPath ||
        // Skip if the member is already assigned a role that uses a seat because the seat usage won't increase.
        this.member.usingLicense ||
        // Skip if the new role does not occupy a seat because it won't cause an overage.
        !this.role.occupiesSeat
      );
    },
    isGroup() {
      return Boolean(this.member.sharedWithGroup);
    },
  },
  methods: {
    // Check to see if changing the role would increase the seat usage and cause an overage, and if so, show a warning
    // modal. Otherwise, act as if the overage warning was accepted and emit the confirm event.
    async confirmOverage() {
      try {
        if (this.shouldSkipConfirmationCheck) {
          this.emitConfirm();
          return;
        }

        const response = await this.$apollo.query({
          query: getBillableUserCountChanges,
          fetchPolicy: fetchPolicies.NO_CACHE,
          variables: {
            fullPath: this.groupPath,
            addGroupId: this.isGroup ? this.member.id : null,
            addUserIds: this.isGroup ? null : [this.member.id],
            addUserEmails: [],
            role: ACCESS_LEVEL_LABELS[this.role.accessLevel].toUpperCase(),
            memberRoleId: this.role.memberRoleId,
          },
        });

        const { willIncreaseOverage, seatsInSubscription, newBillableUserCount } =
          response?.data?.group?.gitlabSubscriptionsPreviewBillableUserChange || {};
        // If the overage won't increase or if there's no subscription data, don't show the modal.
        if (!willIncreaseOverage || isNil(seatsInSubscription) || isNil(newBillableUserCount)) {
          this.emitConfirm();
          return;
        }

        // Overage check is valid, set a bunch of values and show the modal.
        this.groupName = response.data.group.name;
        this.seatsInSubscription = seatsInSubscription;
        this.newBillableUserCount = newBillableUserCount;
        this.isModalVisible = true;
      } catch (error) {
        this.$emit('error', error);
      }
    },
    emitConfirm() {
      this.$emit('confirm');
    },
  },
  actionPrimary: { text: s__('MembersOverage|Continue with overages') },
  actionCancel: { text: __('Cancel') },
};
</script>

<template>
  <gl-modal
    ref="modal"
    v-model="isModalVisible"
    modal-id="guest-overage-confirmation-modal"
    :title="s__('MembersOverage|You are about to incur additional charges')"
    :action-primary="$options.actionPrimary"
    :action-cancel="$options.actionCancel"
    size="sm"
    no-focus-on-show
    @primary="emitConfirm"
    @canceled="$emit('cancel')"
  >
    {{ currentSeatCountMessage }}
    <gl-sprintf :message="newSeatCountMessage">
      <template #groupName>{{ groupName }}</template>
      <template #seatCount>{{ newBillableUserCount }}</template>
    </gl-sprintf>
    <gl-link :href="reconciliationDocsPath" target="_blank" class="gl-display-inline-block">
      {{ __('Learn more') }}
      <gl-icon name="external-link" />
    </gl-link>
  </gl-modal>
</template>
