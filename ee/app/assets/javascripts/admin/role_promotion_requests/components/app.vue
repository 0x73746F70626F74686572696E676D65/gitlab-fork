<script>
import { GlKeysetPagination, GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DEFAULT_PER_PAGE } from '~/api';
import usersQueuedForLicenseSeat from '../graphql/users_queued_for_license_seat.query.graphql';
import PromotionRequestsTable from './promotion_requests_table.vue';

export default {
  name: 'RolePromotionRequestsApp',
  components: {
    PromotionRequestsTable,
    GlKeysetPagination,
    GlAlert,
  },
  data() {
    return {
      isLoading: true,
      error: false,
      usersQueuedForLicenseSeat: {},
      cursor: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
    };
  },
  apollo: {
    usersQueuedForLicenseSeat: {
      query: usersQueuedForLicenseSeat,
      variables() {
        return {
          ...this.cursor,
        };
      },
      update(data) {
        return data.selfManagedUsersQueuedForRolePromotion;
      },
      error(error) {
        this.isLoading = false;
        this.error = true;
        Sentry.captureException({ error, component: this.$options.name });
      },
      result() {
        this.isLoading = false;
      },
    },
  },
  methods: {
    onPrev(before) {
      this.cursor = {
        first: DEFAULT_PER_PAGE,
        last: null,
        before,
      };
    },
    onNext(after) {
      this.cursor = {
        first: null,
        last: DEFAULT_PER_PAGE,
        after,
      };
    },
  },
};
</script>

<template>
  <section>
    <gl-alert v-if="error" variant="danger" :dismissible="false" class="gl-my-4">
      {{
        s__(
          'PromotionRequests|An error occured while loading the role promotion requests. Please refresh the page to try again.',
        )
      }}
    </gl-alert>

    <promotion-requests-table :is-loading="isLoading" :list="usersQueuedForLicenseSeat.nodes" />

    <div class="gl--flex-center gl-mt-4">
      <gl-keyset-pagination
        v-bind="usersQueuedForLicenseSeat.pageInfo"
        :disabled="isLoading"
        @prev="onPrev"
        @next="onNext"
      />
    </div>
  </section>
</template>
