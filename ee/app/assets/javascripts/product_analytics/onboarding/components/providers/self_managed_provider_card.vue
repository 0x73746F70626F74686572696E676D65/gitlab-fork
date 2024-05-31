<script>
import { GlButton, GlFormCheckbox, GlLink, GlSprintf } from '@gitlab/ui';
import CloudUserIllustrationPath from '@gitlab/svgs/dist/illustrations/cloud-user-sm.svg';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { s__ } from '~/locale';

import ProviderSettingsPreview from './provider_settings_preview.vue';
import { getRedirectConfirmationMessage } from './utils';

export default {
  name: 'SelfManagedProviderCard',
  components: { GlButton, GlFormCheckbox, GlLink, GlSprintf, ProviderSettingsPreview },
  inject: {
    projectLevelAnalyticsProviderSettings: {},
    isInstanceConfiguredWithSelfManagedAnalyticsProvider: {
      default: false,
    },
    defaultUseInstanceConfiguration: {
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
      useInstanceConfiguration: this.defaultUseInstanceConfiguration,
    };
  },
  computed: {
    hasAllProjectLevelSettings() {
      return Object.values(this.projectLevelAnalyticsProviderSettings).every(Boolean);
    },
    hasEmptyProjectLevelSettings() {
      return !Object.values(this.projectLevelAnalyticsProviderSettings).some(Boolean);
    },
    hasValidProviderConfig() {
      if (this.useInstanceConfiguration) {
        return (
          this.hasEmptyProjectLevelSettings &&
          this.isInstanceConfiguredWithSelfManagedAnalyticsProvider
        );
      }

      return this.hasAllProjectLevelSettings;
    },
  },
  methods: {
    async onSelected() {
      if (!this.hasValidProviderConfig) {
        await this.promptToSetSettings();
        return;
      }

      this.$emit('confirm', CloudUserIllustrationPath);
    },
    async promptToSetSettings() {
      const redirectMessage = this.useInstanceConfiguration
        ? s__(
            `ProductAnalytics|To connect to your instance-level provider, you must first remove project-level provider configuration. You'll be redirected to the %{analyticsSettingsLink} page, which shows your provider's configuration settings and setup instructions.`,
          )
        : s__(
            `ProductAnalytics|To connect your own provider, you'll be redirected to the %{analyticsSettingsLink} page, which shows your provider's configuration settings and setup instructions.`,
          );

      const confirmed = await confirmAction('', {
        title: s__('ProductAnalytics|Connect your own provider'),
        primaryBtnText: s__('ProductAnalytics|Go to analytics settings'),
        modalHtmlMessage: getRedirectConfirmationMessage(
          redirectMessage,
          this.projectAnalyticsSettingsPath,
        ),
      });

      if (confirmed) {
        this.$emit('open-settings');
      }
    },
  },
  CloudUserIllustrationPath,
};
</script>
<template>
  <div
    class="gl-display-flex gl-gap-6 gl-border-gray-100 gl-border-solid border-radius-default gl-w-full gl-p-6"
  >
    <div class="gl-flex-shrink-0 gl-hidden md:gl-block">
      <img class="gl-dark-invert-keep-hue" :src="$options.CloudUserIllustrationPath" :alt="''" />
    </div>
    <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-1 gl-w-full">
      <h3 class="gl-mt-0 text-4">
        {{ s__('ProductAnalytics|Self-managed provider') }}
      </h3>
      <p class="gl-mb-6">
        {{
          s__(
            'ProductAnalytics|Manage your own analytics provider to process, store, and query analytics data.',
          )
        }}
      </p>
      <gl-form-checkbox
        v-if="isInstanceConfiguredWithSelfManagedAnalyticsProvider"
        v-model="useInstanceConfiguration"
        class="gl-mb-6"
        data-testid="use-instance-configuration-checkbox"
        >{{ s__('ProductAnalytics|Use instance-level settings') }}
        <template #help>{{
          s__(
            'ProductAnalytics|Uncheck if you would like to configure a different provider for this project.',
          )
        }}</template>
      </gl-form-checkbox>
      <p v-if="useInstanceConfiguration">
        {{
          s__(
            'ProductAnalytics|Your instance will be created on the provider configured in your instance settings.',
          )
        }}
      </p>
      <template v-else-if="hasValidProviderConfig">
        <p>{{ s__('ProductAnalytics|Your instance will be created on this provider:') }}</p>
        <provider-settings-preview
          :configurator-connection-string="
            projectLevelAnalyticsProviderSettings.productAnalyticsConfiguratorConnectionString
          "
          :collector-host="projectLevelAnalyticsProviderSettings.productAnalyticsDataCollectorHost"
          :cube-api-base-url="projectLevelAnalyticsProviderSettings.cubeApiBaseUrl"
          :cube-api-key="projectLevelAnalyticsProviderSettings.cubeApiKey"
        />
      </template>
      <template v-else>
        <h4 class="gl-font-lg gl-mt-0">{{ s__('ProductAnalytics|For this option, you need:') }}</h4>
        <ul class="gl-mb-6">
          <li>
            <gl-sprintf
              :message="
                s__(
                  'ProductAnalytics|A deployed instance of the %{linkStart}helm-charts%{linkEnd} project.',
                )
              "
            >
              <template #link="{ content }">
                <gl-link
                  href="https://gitlab.com/gitlab-org/analytics-section/product-analytics/helm-charts"
                  target="_blank"
                  >{{ content }}</gl-link
                >
              </template>
            </gl-sprintf>
          </li>
          <li>{{ s__('ProductAnalytics|Valid project settings.') }}</li>
        </ul>
      </template>

      <gl-button
        category="primary"
        variant="confirm"
        class="gl-mt-auto gl-align-self-start"
        data-testid="connect-your-own-provider-btn"
        @click="onSelected"
        >{{ s__('ProductAnalytics|Connect your own provider') }}</gl-button
      >
    </div>
  </div>
</template>
