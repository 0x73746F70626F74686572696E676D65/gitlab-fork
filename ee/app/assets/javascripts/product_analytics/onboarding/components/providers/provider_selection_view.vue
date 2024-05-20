<script>
import { GlEmptyState, GlLink, GlLoadingIcon, GlSprintf } from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';
import { setUrlFragment } from '~/lib/utils/url_utility';

import initializeProductAnalyticsMutation from '../../../graphql/mutations/initialize_product_analytics.mutation.graphql';
import SelfManagedProviderCard from './self_managed_provider_card.vue';
import GitlabManagedProviderCard from './gitlab_managed_provider_card.vue';

export default {
  name: 'ProviderSelectionPage',
  components: {
    GitlabManagedProviderCard,
    GlEmptyState,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    SelfManagedProviderCard,
  },
  inject: {
    analyticsSettingsPath: {},
    namespaceFullPath: {},
    projectLevelAnalyticsProviderSettings: {},
  },
  props: {
    loadingInstance: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      loading: this.loadingInstance,
      loadingStateSvgPath: null,
    };
  },
  computed: {
    projectAnalyticsSettingsPath() {
      return setUrlFragment(this.analyticsSettingsPath, '#js-analytics-data-sources');
    },
  },
  methods: {
    onConfirm(loadingStateSvgPath) {
      this.loadingStateSvgPath = loadingStateSvgPath;
      this.loading = true;
      this.initialize();
    },
    onError(err) {
      this.loading = false;
      this.$emit('error', err);
    },
    async initialize() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: initializeProductAnalyticsMutation,
          variables: {
            projectPath: this.namespaceFullPath,
          },
        });

        const [error] = data?.projectInitializeProductAnalytics?.errors || [];

        if (error) {
          this.onError(new Error(error));
        } else {
          this.$emit('initialized');
        }
      } catch (err) {
        this.onError(err);
      }
    },
    openSettings() {
      window.open(this.projectAnalyticsSettingsPath, '_blank');
    },
  },
  docsPath: helpPagePath('user/product_analytics/index', {
    anchor: 'onboard-a-gitLab-project',
  }),
};
</script>

<template>
  <section>
    <gl-empty-state
      v-if="loading"
      :title="s__('ProductAnalytics|Creating your product analytics instance...')"
      :svg-path="loadingStateSvgPath"
      :svg-height="null"
    >
      <template #description>
        <p class="gl-max-w-80">
          {{
            s__(
              'ProductAnalytics|This might take a while, feel free to navigate away from this page and come back later.',
            )
          }}
        </p>
      </template>
      <template #actions>
        <gl-loading-icon size="lg" class="gl-mt-5" />
      </template>
    </gl-empty-state>

    <section v-else>
      <h1>{{ s__('ProductAnalytics|Analyze your product with Product Analytics') }}</h1>
      <p>
        <gl-sprintf
          :message="
            s__(
              `ProductAnalytics|Set up Product Analytics to track how your product is performing. Combine analytics with your GitLab data to better understand where you can improve your product and development processes. %{linkStart}Learn more%{linkEnd}.`,
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.docsPath" target="_blank" rel="noopener noreferrer">
              {{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </p>
      <h2>{{ __('Select an option') }}</h2>
      <div class="gl-display-flex gl-flex-wrap gl-md-flex-nowrap gl-gap-5">
        <self-managed-provider-card
          :project-analytics-settings-path="projectAnalyticsSettingsPath"
          @confirm="onConfirm"
          @open-settings="openSettings"
        />
        <gitlab-managed-provider-card @confirm="onConfirm" />
      </div>
    </section>
  </section>
</template>
