<script>
import { GlEmptyState, GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { __, s__ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { codeSuggestionsLearnMoreLink } from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';

export default {
  name: 'CodeSuggestionsIntro',
  helpLinks: {
    codeSuggestionsLearnMoreLink,
  },
  i18n: {
    contactSales: __('Contact sales'),
    purchaseSeats: __('Purchase seats'),
    description: s__(
      `CodeSuggestions|Enhance your coding experience with intelligent recommendations. %{linkStart}GitLab Duo Pro%{linkEnd} offers features that use generative AI to suggest code.`,
    ),
    title: s__('CodeSuggestions|Introducing GitLab Duo Pro'),
  },
  handRaiseLeadAttributes: {
    variant: 'confirm',
    category: 'tertiary',
    class: 'gl-sm-w-auto gl-w-full gl-sm-ml-3 gl-sm-mt-0 gl-mt-3',
    'data-testid': 'code-suggestions-hand-raise-lead-button',
  },
  ctaTracking: {
    action: 'click_button',
    label: 'code_suggestions_hand_raise_lead_form',
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
  },
  apolloProvider,
  inject: {
    addDuoProHref: { default: null },
  },
  emptyStateSvgUrl,
};
</script>
<template>
  <gl-empty-state :svg-path="$options.emptyStateSvgUrl">
    <template #title>
      <h1 v-safe-html="$options.i18n.title" class="gl-font-size-h-display gl-leading-36 h4"></h1>
    </template>
    <template #description>
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.helpLinks.codeSuggestionsLearnMoreLink" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #actions>
      <gl-button
        :href="addDuoProHref"
        variant="confirm"
        category="primary"
        class="gl-sm-w-auto gl-w-full"
      >
        {{ $options.i18n.purchaseSeats }}
      </gl-button>
      <hand-raise-lead-button
        :button-attributes="$options.handRaiseLeadAttributes"
        glm-content="code-suggestions"
        product-interaction="Requested Contact-Duo Pro Add-On"
        :cta-tracking="$options.ctaTracking"
      />
    </template>
  </gl-empty-state>
</template>
