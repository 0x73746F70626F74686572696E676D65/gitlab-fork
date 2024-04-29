<script>
import { GlButton, GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import CloudTanukiIllustrationPath from '@gitlab/svgs/dist/illustrations/cloud-tanuki-sm.svg';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { PROMO_URL } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';

import { getRedirectConfirmationMessage } from './utils';

export default {
  name: 'GitlabManagedProviderCard',
  components: { GlButton, GlFormCheckbox, GlSprintf },
  inject: {
    projectLevelAnalyticsProviderSettings: {
      default: () => ({}),
    },
    managedClusterPurchased: {
      default: false,
    },
  },
  props: {
    projectAnalyticsSettingsPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasAgreedToGCPZone: false,
      gcpZoneError: null,
    };
  },
  computed: {
    hasAnyProjectLevelProviderConfig() {
      return Object.values(this.projectLevelAnalyticsProviderSettings).some(Boolean);
    },
  },
  methods: {
    async onSelected() {
      if (!this.ensureAgreedToGcpZone()) {
        return;
      }

      if (this.hasAnyProjectLevelProviderConfig) {
        await this.promptToClearSettings();
        return;
      }

      this.$emit('confirm', CloudTanukiIllustrationPath);
    },
    ensureAgreedToGcpZone() {
      if (this.hasAgreedToGCPZone) {
        this.gcpZoneError = null;
        return true;
      }

      this.gcpZoneError = s__(
        'ProductAnalytics|To continue, you must agree to event storage and processing in this region.',
      );
      return false;
    },
    async promptToClearSettings() {
      const confirmed = await confirmAction('', {
        title: s__('ProductAnalytics|Reset existing project provider settings'),
        primaryBtnText: s__('ProductAnalytics|Go to analytics settings'),
        modalHtmlMessage: getRedirectConfirmationMessage(
          s__(
            `ProductAnalytics|This project uses the provider configuration. To connect to a GitLab-managed provider, you'll be redirected to the %{analyticsSettingsLink} page where you must remove the current configuration.`,
          ),
          this.projectAnalyticsSettingsPath,
        ),
      });

      if (confirmed) {
        this.$emit('open-settings');
      }
    },
  },
  zone: 'us-central-1',
  contactSalesUrl: `${PROMO_URL}/sales/`,
  CloudTanukiIllustrationPath,
};
</script>
<template>
  <div
    class="gl-display-flex gl-gap-6 gl-border-gray-100 gl-border-solid border-radius-default gl-w-full gl-p-6"
  >
    <div class="gl-flex-shrink-0 gl-display-none gl-md-display-block">
      <img class="gl-dark-invert-keep-hue" :src="$options.CloudTanukiIllustrationPath" :alt="''" />
    </div>
    <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-1 gl-w-full">
      <h3 class="gl-mt-0 text-4">
        {{ s__('ProductAnalytics|GitLab-managed provider') }}
      </h3>
      <p class="gl-mb-6">
        {{
          s__(
            'ProductAnalytics|Use a GitLab-managed infrastructure to process, store, and query analytics events data.',
          )
        }}
      </p>
      <h4 class="gl-font-lg gl-mt-0">{{ s__('ProductAnalytics|For this option:') }}</h4>
      <ul class="gl-mb-6">
        <li>
          {{
            s__(
              'ProductAnalytics|This feature is in Beta and requires purchasing a quota of events, which you receive on each billing period.',
            )
          }}
        </li>
        <li>
          <gl-sprintf
            :message="
              s__(
                'ProductAnalytics|The Product Analytics Beta on GitLab.com is offered only in the Google Cloud Platform zone %{zone}.',
              )
            "
          >
            <template #zone>
              <code class="gl-white-space-nowrap">{{ $options.zone }}</code>
            </template>
          </gl-sprintf>
        </li>
      </ul>
      <template v-if="managedClusterPurchased">
        <div class="gl-mb-6 gl-mt-auto">
          <gl-form-checkbox v-model="hasAgreedToGCPZone" data-testid="region-agreement-checkbox">{{
            s__('ProductAnalytics|I agree to event collection and processing in this region.')
          }}</gl-form-checkbox>
          <div v-if="gcpZoneError" class="gl-text-red-500" data-testid="gcp-zone-error">
            {{ gcpZoneError }}
          </div>
        </div>
        <gl-button
          category="primary"
          variant="confirm"
          class="gl-align-self-start"
          data-testid="connect-gitlab-managed-provider-btn"
          @click="onSelected"
          >{{ s__('ProductAnalytics|Use GitLab-managed provider') }}</gl-button
        >
      </template>
      <gl-button
        v-else
        category="primary"
        variant="confirm"
        class="gl-align-self-start"
        data-testid="contact-sales-team-btn"
        :href="$options.contactSalesUrl"
        >{{ s__('ProductAnalytics|Contact our sales team') }}</gl-button
      >
    </div>
  </div>
</template>
