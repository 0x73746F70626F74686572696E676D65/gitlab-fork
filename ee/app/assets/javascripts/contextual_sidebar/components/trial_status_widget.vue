<script>
import { GlLink, GlProgressBar, GlIcon, GlButton } from '@gitlab/ui';
import { removeTrialSuffix } from 'ee/billings/billings_util';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import { WIDGET } from './constants';

const { i18n, trackingEvents } = WIDGET;
const trackingMixin = Tracking.mixin();

export default {
  components: {
    GlLink,
    GlProgressBar,
    GlIcon,
    GlButton,
  },
  mixins: [trackingMixin],
  inject: {
    containerId: { default: null },
    trialDaysUsed: {},
    trialDuration: {},
    navIconImagePath: {},
    percentageComplete: {},
    planName: {},
    trialDiscoverPagePath: {},
  },
  i18n,
  computed: {
    isTrialActive() {
      return this.percentageComplete <= 100;
    },
    widgetTitle() {
      if (this.isTrialActive) {
        return sprintf(i18n.widgetTitle, { planName: removeTrialSuffix(this.planName) });
      }
      return i18n.widgetTitleExpiredTrial;
    },
    widgetRemainingDays() {
      return sprintf(i18n.widgetRemainingDays, {
        daysUsed: this.trialDaysUsed,
        duration: this.trialDuration,
      });
    },
    trackingOptions() {
      return this.isTrialActive
        ? trackingEvents.activeTrialOptions
        : trackingEvents.trialEndedOptions;
    },
  },
  methods: {
    onLearnAboutFeaturesClick() {
      this.track(trackingEvents.action, { ...this.trackingOptions, label: 'learn_about_features' });
    },
    onWidgetClick() {
      this.track(trackingEvents.action, { ...this.trackingOptions });
    },
  },
};
</script>

<template>
  <gl-link :id="containerId" :title="widgetTitle" :href="trialDiscoverPagePath">
    <div
      data-testid="trial-widget-menu"
      class="gl-display-flex gl-flex-direction-column gl-align-items-stretch gl-w-full"
      @click="onWidgetClick"
    >
      <div v-if="isTrialActive">
        <div class="gl-display-flex gl-w-full gl-align-items-center">
          <span class="nav-icon-container svg-container gl-mr-3 gl-mb-1">
            <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
            <img alt="" :src="navIconImagePath" width="16" class="svg" />
          </span>
          <span class="nav-item-name gl-flex-grow-1">
            {{ widgetTitle }}
          </span>
          <span class="gl-whitespace-nowrap gl-overflow-hidden gl-font-sm gl-mr-auto">
            {{ widgetRemainingDays }}
          </span>
        </div>
        <div class="gl-display-flex gl-align-items-stretch gl-mt-2">
          <gl-progress-bar :value="percentageComplete" class="gl-flex-grow-1" aria-hidden="true" />
        </div>

        <gl-button
          :href="trialDiscoverPagePath"
          variant="link"
          size="small"
          class="gl-mt-3 gl-underline"
          data-testid="learn-about-features-btn"
          :title="$options.i18n.learnAboutButtonTitle"
          @click.stop="onLearnAboutFeaturesClick()"
        >
          {{ $options.i18n.learnAboutButtonTitle }}
        </gl-button>
      </div>
      <div v-else class="gl-display-flex gl-gap-4 gl-w-full gl-px-2">
        <gl-icon name="information-o" class="gl-text-blue-600! gl-shrink-0" />
        <div>
          <div class="gl-font-bold">
            {{ widgetTitle }}
          </div>
          <div class="gl-mt-3">
            {{ $options.i18n.widgetBodyExpiredTrial }}
            <gl-button
              :href="trialDiscoverPagePath"
              class="gl-mb-1 gl-text-black-normal! gl-underline"
              variant="link"
              size="small"
              data-testid="learn-about-features-btn"
              :title="$options.i18n.learnAboutButtonTitle"
              @click.stop="onLearnAboutFeaturesClick()"
            >
              {{ $options.i18n.learnAboutButtonTitle }}
            </gl-button>
          </div>
        </div>
      </div>
    </div>
  </gl-link>
</template>
