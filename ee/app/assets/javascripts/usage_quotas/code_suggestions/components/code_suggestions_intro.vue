<script>
import { GlEmptyState, GlLink, GlSprintf, GlButton, GlIntersectionObserver } from '@gitlab/ui';
import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { __, s__ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import {
  codeSuggestionsLearnMoreLink,
  VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD,
} from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';
import Tracking, { InternalEvents } from '~/tracking';

export default {
  name: 'CodeSuggestionsIntro',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    purchaseSeats: __('Purchase seats'),
    trial: __('Start a trial'),
    description: s__(
      `CodeSuggestions|Enhance your coding experience with intelligent recommendations. %{linkStart}GitLab Duo Pro%{linkEnd} offers features that use generative AI to suggest code.`,
    ),
    title: s__('CodeSuggestions|Introducing GitLab Duo Pro'),
  },
  directives: {
    SafeHtml,
  },
  components: {
    HandRaiseLeadButton,
    GlEmptyState,
    GlLink,
    GlSprintf,
    GlButton,
    GlIntersectionObserver,
  },
  mixins: [Tracking.mixin(), InternalEvents.mixin()],
  inject: {
    duoProTrialHref: { default: null },
    addDuoProHref: { default: null },
    handRaiseLeadData: { default: {} },
  },
  computed: {
    purchaseSeatsBtnCategory() {
      return this.duoProTrialHref ? 'secondary' : 'primary';
    },
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD);
  },
  methods: {
    trackPageView() {
      if (this.duoProTrialHref) {
        this.track('pageview', { label: 'duo_pro_add_on_tab_pre_trial' });
      }
    },
    trackTrialClick() {
      this.track('click_button', { label: 'duo_pro_start_trial' });
    },
    trackPurchaseSeatsClick() {
      this.track('click_button', { label: 'duo_pro_purchase_seats' });
    },
    trackLearnMoreClick() {
      this.track('click_link', { label: 'duo_pro_marketing_page' });
    },
  },
  apolloProvider,
  emptyStateSvgUrl,
};
</script>
<template>
  <gl-intersection-observer @appear="trackPageView">
    <gl-empty-state :svg-path="$options.emptyStateSvgUrl">
      <template #title>
        <h1 v-safe-html="$options.i18n.title" class="gl-font-size-h-display gl-leading-36 h4"></h1>
      </template>
      <template #description>
        <gl-sprintf :message="$options.i18n.description">
          <template #link="{ content }">
            <gl-link
              :href="$options.helpLinks.codeSuggestionsLearnMoreLink"
              target="_blank"
              class="gl-text-decoration-underline"
              data-testid="duo-pro-learn-more-link"
              @click="trackLearnMoreClick"
            >
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #actions>
        <gl-button
          v-if="duoProTrialHref"
          :href="duoProTrialHref"
          variant="confirm"
          category="primary"
          class="gl-sm-w-auto gl-w-full"
          data-testid="duo-pro-start-trial-btn"
          @click="trackTrialClick"
        >
          {{ $options.i18n.trial }}
        </gl-button>
        <gl-button
          :href="addDuoProHref"
          variant="confirm"
          :category="purchaseSeatsBtnCategory"
          class="sm:gl-w-auto gl-w-full sm:gl-ml-3 sm:gl-mt-0 gl-mt-3"
          data-testid="duo-pro-purchase-seats-btn"
          @click="trackPurchaseSeatsClick"
        >
          {{ $options.i18n.purchaseSeats }}
        </gl-button>
        <hand-raise-lead-button
          :button-attributes="handRaiseLeadData.buttonAttributes"
          :glm-content="handRaiseLeadData.glmContent"
          :product-interaction="handRaiseLeadData.productInteraction"
          :cta-tracking="handRaiseLeadData.ctaTracking"
        />
      </template>
    </gl-empty-state>
  </gl-intersection-observer>
</template>
