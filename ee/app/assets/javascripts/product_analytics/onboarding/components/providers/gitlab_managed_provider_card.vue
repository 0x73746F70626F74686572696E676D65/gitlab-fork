<script>
import { GlButton, GlFormCheckbox, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import CloudTanukiIllustrationPath from '@gitlab/svgs/dist/illustrations/cloud-tanuki-sm.svg';

import { PROMO_URL } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';

import productAnalyticsProjectSettingsUpdate from '../../../graphql/mutations/product_analytics_project_settings_update.mutation.graphql';

export default {
  name: 'GitlabManagedProviderCard',
  components: { GlButton, GlFormCheckbox, GlLink, GlModal, GlSprintf },
  inject: {
    projectLevelAnalyticsProviderSettings: {
      default: () => ({}),
    },
    analyticsSettingsPath: {},
    managedClusterPurchased: {
      default: false,
    },
    namespaceFullPath: {},
  },
  data() {
    return {
      projectSettings: this.projectLevelAnalyticsProviderSettings,
      hasAgreedToGCPZone: false,
      gcpZoneError: null,
      clearSettingsModalIsVisible: false,
      clearSettingsModalIsLoading: false,
      clearSettingsModalHasError: false,
    };
  },
  computed: {
    hasAnyProjectLevelProviderConfig() {
      return Object.values(this.projectSettings).some(Boolean);
    },
    modalPrimaryAction() {
      return {
        text: __('Continue'),
        attributes: {
          variant: 'confirm',
          loading: this.clearSettingsModalIsLoading,
        },
      };
    },
    modalCancelAction() {
      return {
        text: __('Cancel'),
        attributes: {
          disabled: this.clearSettingsModalIsLoading,
        },
      };
    },
  },
  methods: {
    async onSelected() {
      if (!this.ensureAgreedToGcpZone()) {
        return;
      }

      if (this.hasAnyProjectLevelProviderConfig) {
        this.clearSettingsModalIsVisible = true;
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
    onCancelClearSettings() {
      this.clearSettingsModalIsVisible = false;
    },
    async onConfirmClearSettings() {
      this.clearSettingsModalHasError = false;
      this.clearSettingsModalIsLoading = true;

      const { data } = await this.$apollo.mutate({
        mutation: productAnalyticsProjectSettingsUpdate,
        variables: {
          fullPath: this.namespaceFullPath,
          productAnalyticsConfiguratorConnectionString: null,
          productAnalyticsDataCollectorHost: null,
          cubeApiBaseUrl: null,
          cubeApiKey: null,
        },
      });

      this.clearSettingsModalIsLoading = false;
      const { errors, __typename, ...updatedProjectSetting } =
        data.productAnalyticsProjectSettingsUpdate;

      if (errors?.length) {
        this.clearSettingsModalHasError = true;
        return;
      }

      this.clearSettingsModalIsVisible = false;
      this.projectSettings = updatedProjectSetting;
      await this.onSelected();
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
    <div class="gl-flex-shrink-0 gl-hidden md:gl-block">
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
              <code class="gl-whitespace-nowrap">{{ $options.zone }}</code>
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
    <gl-modal
      :visible="clearSettingsModalIsVisible"
      :action-primary="modalPrimaryAction"
      :action-cancel="modalCancelAction"
      data-testid="clear-project-level-settings-confirmation-modal"
      modal-id="clear-project-level-settings-confirmation-modal"
      :title="s__('ProductAnalytics|Reset existing project provider settings')"
      @primary="onConfirmClearSettings"
      @canceled="onCancelClearSettings"
    >
      {{
        s__(
          `ProductAnalytics|This project has analytics provider settings configured. If you continue, these project-level settings will be reset so that GitLab-managed provider settings can be used.`,
        )
      }}
      <p
        v-if="clearSettingsModalHasError"
        class="gl-text-red-500 gl-mt-5"
        data-testid="clear-project-level-settings-confirmation-modal-error"
      >
        <gl-sprintf
          :message="
            s__(
              'Analytics|Failed to clear project-level settings. Please try again or %{linkStart}clear them manually%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="analyticsSettingsPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-modal>
  </div>
</template>
