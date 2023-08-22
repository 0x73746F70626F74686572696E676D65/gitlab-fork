<script>
import { GlTableLite, GlBadge, GlLink } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { formatDate } from '~/lib/utils/datetime_utility';
import { membershipDetailsFields } from '../constants';
import SubscriptionSeatDetailsLoader from './subscription_seat_details_loader.vue';

export default {
  components: {
    GlBadge,
    GlTableLite,
    GlLink,
    SubscriptionSeatDetailsLoader,
  },
  props: {
    seatMemberId: {
      type: Number,
      required: true,
    },
  },
  computed: {
    ...mapState({
      userDetailsEntry(state) {
        return state.userDetails[this.seatMemberId];
      },
    }),
    items() {
      return this.userDetailsEntry.items;
    },
    isLoaderShown() {
      return this.userDetailsEntry.isLoading || this.userDetailsEntry.hasError;
    },
    fields() {
      return membershipDetailsFields(this.userDetailsEntry.hasIndirectMembership);
    },
  },
  created() {
    this.fetchBillableMemberDetails(this.seatMemberId);
  },
  methods: {
    ...mapActions(['fetchBillableMemberDetails']),
    formatDate,
  },
};
</script>

<template>
  <div v-if="isLoaderShown">
    <subscription-seat-details-loader />
  </div>
  <gl-table-lite v-else :fields="fields" :items="items" data-testid="seat-usage-details">
    <template #cell(source_full_name)="{ item }">
      <gl-link :href="item.source_members_url" target="_blank">{{ item.source_full_name }}</gl-link>
    </template>
    <template #cell(created_at)="{ item }">
      <span>{{ formatDate(item.created_at, 'yyyy-mm-dd') }}</span>
    </template>
    <template #cell(expires_at)="{ item }">
      <span>{{ item.expires_at ? formatDate(item.expires_at, 'yyyy-mm-dd') : __('Never') }}</span>
    </template>
    <template #cell(role)="{ item }">
      <template v-if="item.access_level.custom_role">
        <div>{{ item.access_level.custom_role.name }}</div>
        <gl-badge class="gl-mt-3">{{ s__('MemberRole|Custom role') }}</gl-badge>
      </template>
      <template v-else>{{ item.access_level.string_value }}</template>
    </template>
  </gl-table-lite>
</template>
