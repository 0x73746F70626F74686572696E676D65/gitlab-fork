<script>
import { GlEmptyState, GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { __, s__ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { codeSuggestionsLearnMoreLink } from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLead from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead.vue';
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
  directives: {
    SafeHtml,
  },
  components: {
    HandRaiseLead,
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
      <h1
        v-safe-html="$options.i18n.title"
        class="gl-font-size-h-display gl-line-height-36 h4"
      ></h1>
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
      <gl-button :href="addDuoProHref" variant="confirm" category="primary">
        {{ $options.i18n.purchaseSeats }}
      </gl-button>
      <hand-raise-lead class="gl-sm-ml-3 gl-ml-0" />
    </template>
  </gl-empty-state>
</template>
