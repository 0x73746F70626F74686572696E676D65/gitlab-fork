<script>
import { GlButton, GlPopover, GlSprintf } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import { debounce } from 'lodash';
import { formatDate } from '~/lib/utils/datetime_utility';
import { n__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import {
  RESIZE_EVENT,
  RESIZE_EVENT_DEBOUNCE_MS,
  DUO_PRO_TRIAL_POPOVER_CONTENT,
  DUO_PRO_TRIAL_POPOVER_LEARN_TITLE,
  DUO_PRO_TRIAL_POPOVER_LEARN_URL,
  DUO_PRO_TRIAL_POPOVER_PURCHASE_TITLE,
  DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
  POPOVER_HIDE_DELAY,
} from './constants';

export default {
  components: {
    GlButton,
    GlPopover,
    GlSprintf,
  },
  mixins: [Tracking.mixin({ category: DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY })],
  inject: {
    daysRemaining: {
      type: Number,
      default: null,
    },
    containerId: {
      type: String,
      default: '',
    },
    purchaseNowUrl: {
      type: String,
      default: '',
    },
    targetId: {
      type: String,
      default: '',
    },
    trialEndDate: {
      type: Date,
      default: null,
    },
  },
  data() {
    return {
      disabled: false,
    };
  },
  popoverContent: DUO_PRO_TRIAL_POPOVER_CONTENT,
  purchaseNowTitle: DUO_PRO_TRIAL_POPOVER_PURCHASE_TITLE,
  learnAboutButtonTitle: DUO_PRO_TRIAL_POPOVER_LEARN_TITLE,
  learnAboutButtonUrl: DUO_PRO_TRIAL_POPOVER_LEARN_URL,
  hideDelay: { hide: POPOVER_HIDE_DELAY },
  popoverClasses: ['gl-p-2'],
  computed: {
    formattedTrialEndDate() {
      return formatDate(this.trialEndDate, 'mmmm d', true);
    },
    popoverTitle() {
      const i18nPopoverTitle = n__(
        "DuoProTrial|You've got %{daysRemaining} day remaining on your GitLab Duo Pro trial!",
        "DuoProTrial|You've got %{daysRemaining} days remaining on your GitLab Duo Pro trial!",
        this.daysRemaining,
      );

      return sprintf(i18nPopoverTitle, {
        daysRemaining: this.daysRemaining,
      });
    },
    popoverContent() {
      return sprintf(this.$options.popoverContent, {
        trialEndDate: this.formattedTrialEndDate,
      });
    },
  },
  created() {
    this.debouncedResize = debounce(() => this.updateDisabledState(), RESIZE_EVENT_DEBOUNCE_MS);
    window.addEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  mounted() {
    this.updateDisabledState();
  },
  beforeDestroy() {
    window.removeEventListener(RESIZE_EVENT, this.debouncedResize);
  },
  methods: {
    purchaseAction() {
      this.track('click_button', { label: 'purchase_now' });
    },
    learnAction() {
      this.track('click_button', { label: 'learn_about_features' });
    },
    updateDisabledState() {
      this.disabled = ['xs', 'sm'].includes(bp.getBreakpointSize());
    },
    onShown() {
      this.track('render_popover');
    },
  },
};
</script>

<template>
  <gl-popover
    ref="popover"
    placement="rightbottom"
    boundary="viewport"
    :container="containerId"
    :target="targetId"
    :disabled="disabled"
    :delay="$options.hideDelay"
    :css-classes="$options.popoverClasses"
    data-testid="duo-pro-trial-status-popover"
    @shown="onShown"
  >
    <template #title>
      <div>
        {{ popoverTitle }}
      </div>
    </template>

    <gl-sprintf :message="popoverContent">
      <template #strong="{ content }">
        <strong>{{ content }}</strong>
      </template>
    </gl-sprintf>

    <div class="gl-mt-5">
      <gl-button
        :href="purchaseNowUrl"
        variant="confirm"
        size="small"
        block
        data-testid="purchase-now-btn"
        :title="$options.purchaseNowTitle"
        @click="purchaseAction"
      >
        <span class="gl-text-sm">{{ $options.purchaseNowTitle }}</span>
      </gl-button>

      <gl-button
        :href="$options.learnAboutButtonUrl"
        target="_blank"
        category="secondary"
        variant="confirm"
        size="small"
        block
        data-testid="learn-about-features-btn"
        :title="$options.learnAboutButtonTitle"
        @click="learnAction"
      >
        <span class="gl-text-sm">{{ $options.learnAboutButtonTitle }}</span>
      </gl-button>
    </div>
  </gl-popover>
</template>
