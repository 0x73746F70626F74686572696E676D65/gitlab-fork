<script>
import { GlLink, GlProgressBar } from '@gitlab/ui';
import GITLAB_LOGO_URL from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import { DUO_PRO_TRIAL_WIDGET_TITLE, DUO_PRO_TRIAL_WIDGET_DAYS_TEXT } from './constants';

const trackingMixin = Tracking.mixin();

export default {
  components: {
    GlLink,
    GlProgressBar,
  },
  mixins: [trackingMixin],
  inject: {
    containerId: { default: null },
    trialDaysUsed: {},
    trialDuration: {},
    percentageComplete: {},
    widgetUrl: {},
  },
  widgetTitle: DUO_PRO_TRIAL_WIDGET_TITLE,
  gitlabLogo: GITLAB_LOGO_URL,
  computed: {
    widgetRemainingDays() {
      return sprintf(DUO_PRO_TRIAL_WIDGET_DAYS_TEXT, {
        daysUsed: this.trialDaysUsed,
        duration: this.trialDuration,
      });
    },
  },
  methods: {
    onWidgetClick() {
      this.track('click_link', { category: 'trial_status_widget', label: 'duo_pro_trial' });
    },
  },
};
</script>

<template>
  <gl-link :id="containerId" :title="$options.widgetTitle" :href="widgetUrl">
    <div
      data-testid="duo-pro-trial-widget-menu"
      class="gl-display-flex gl-flex-direction-column gl-align-items-stretch gl-w-full"
      @click="onWidgetClick"
    >
      <div class="gl-display-flex gl-w-full">
        <span class="nav-icon-container svg-container gl-mr-3">
          <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
          <img alt="" :src="$options.gitlabLogo" width="16" class="svg" />
        </span>
        <span class="nav-item-name gl-flex-grow-1">
          {{ $options.widgetTitle }}
        </span>
        <span class="gl-whitespace-nowrap gl-overflow-hidden gl-font-sm gl-mr-auto">
          {{ widgetRemainingDays }}
        </span>
      </div>
      <div class="gl-display-flex gl-align-items-stretch gl-mt-2">
        <gl-progress-bar :value="percentageComplete" class="gl-flex-grow-1" aria-hidden="true" />
      </div>
    </div>
  </gl-link>
</template>
