<script>
import { v4 as uuidv4 } from 'uuid';

import { GlIcon, GlBadge, GlLink, GlTruncateText } from '@gitlab/ui';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import { DASHBOARD_STATUS_BETA } from '../../constants';

const TRUNCATE_BUTTON_ID = `desc-truncate-btn-${uuidv4()}`;

export default {
  name: 'DashboardsListItem',
  components: {
    GlIcon,
    GlBadge,
    GlLink,
    GlTruncateText,
  },
  props: {
    dashboard: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isBuiltInDashboard() {
      return 'userDefined' in this.dashboard && !this.dashboard.userDefined;
    },
    showBetaBadge() {
      return this.dashboard?.status === DASHBOARD_STATUS_BETA;
    },
    showErrorsBadge() {
      return this.dashboard?.errors?.length > 0;
    },
    redirectHref() {
      return joinPaths(window.location.pathname, this.dashboard.slug);
    },
  },
  methods: {
    routeToDashboard(e) {
      const truncateToggleBtn = document.getElementById(TRUNCATE_BUTTON_ID);
      if (e.target === truncateToggleBtn || truncateToggleBtn?.contains(e.target)) {
        return;
      }

      if (this.dashboard.redirect) {
        visitUrl(this.redirectHref);
      } else {
        this.$router.push(this.dashboard.slug);
      }
    },
  },
  truncateTextToggleButtonProps: { id: TRUNCATE_BUTTON_ID },
};
</script>

<template>
  <li
    class="gl-display-flex! gl-px-5! gl-align-items-center gl-hover-cursor-pointer gl-hover-bg-blue-50"
    data-testid="dashboard-list-item"
    @click="routeToDashboard"
  >
    <div class="gl-float-left gl-mr-4 gl-display-flex gl-align-items-center">
      <gl-icon name="dashboard" class="gl-text-gray-200 gl-mr-3" :size="16" />
    </div>
    <div
      class="gl-display-flex gl-align-items-center gl-justify-content-space-between gl-flex-grow-1"
    >
      <div class="gl-display-flex gl-flex-direction-column">
        <div class="gl-display-flex gl-align-items-center">
          <gl-link
            v-if="dashboard.redirect"
            data-testid="dashboard-redirect-link"
            :href="redirectHref"
            class="gl-font-bold gl-leading-normal gl-text-decoration-none!"
            >{{ dashboard.title }}</gl-link
          >
          <router-link
            v-else
            data-testid="dashboard-router-link"
            class="gl-font-bold gl-leading-normal"
            :to="dashboard.slug"
            >{{ dashboard.title }}</router-link
          >
          <gl-badge
            v-if="showBetaBadge"
            data-testid="dashboard-beta-badge"
            class="gl-ml-2"
            size="sm"
          >
            {{ __('Beta') }}
          </gl-badge>
          <gl-badge
            v-if="showErrorsBadge"
            data-testid="dashboard-errors-badge"
            class="gl-ml-2"
            size="sm"
            icon="error"
            icon-size="sm"
            variant="danger"
          >
            {{ __('Contains errors') }}
          </gl-badge>
        </div>
        <gl-truncate-text
          class="gl-leading-normal gl-text-gray-500"
          :toggle-button-props="$options.truncateTextToggleButtonProps"
        >
          {{ dashboard.description }}
        </gl-truncate-text>
      </div>
      <div v-if="isBuiltInDashboard" class="gl-float-right" data-testid="dashboard-by-gitlab">
        <gl-badge variant="muted" icon="tanuki-verified">{{
          s__('Analytics|Created by GitLab')
        }}</gl-badge>
      </div>
    </div>
  </li>
</template>
