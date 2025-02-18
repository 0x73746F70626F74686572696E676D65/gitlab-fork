<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { InternalEvents } from '~/tracking';

import {
  INSTALL_NPM_PACKAGE,
  IMPORT_NPM_PACKAGE,
  INIT_TRACKING,
  HTML_SCRIPT_SETUP,
} from 'ee/product_analytics/onboarding/constants';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'ProductAnalyticsInstrumentationInstructions',
  components: {
    GlLink,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    collectorHost: {
      type: String,
    },
  },
  props: {
    trackingKey: {
      type: String,
      required: true,
    },
    dashboardsPath: {
      type: String,
      required: true,
    },
  },
  mounted() {
    this.trackEvent('user_viewed_instrumentation_directions');
  },
  i18n: {
    sdkClientsTitle: s__('ProductAnalytics|SDK clients'),
    sdkHost: s__('ProductAnalytics|SDK host'),
    sdkHostDescription: s__('ProductAnalytics|The receiver of tracking events'),
    sdkAppId: s__('ProductAnalytics|SDK application ID'),
    sdkAppIdDescription: s__('ProductAnalytics|The sender of tracking events'),
    instrumentAppDescription: s__(
      'ProductAnalytics|You can instrument your application using a JS module or an HTML script. Follow the instructions below for the option you prefer.',
    ),
    jsModuleTitle: s__('ProductAnalytics|Using JS module'),
    addNpmPackage: s__(
      'ProductAnalytics|1. Add the NPM package to your package.json using your preferred package manager',
    ),
    importNpmPackage: s__('ProductAnalytics|2. Import the new package into your JS code'),
    initNpmPackage: s__('ProductAnalytics|3. Initiate the tracking'),
    htmlScriptTag: __('Using HTML script'),
    htmlScriptTagDescription: s__(
      'ProductAnalytics|Add the script to the page and assign the client SDK to window',
    ),
    summaryText: s__(
      'ProductAnalytics|After your application has been instrumented and data is being collected, you can visualize and monitor behaviors in your %{linkStart}analytics dashboards%{linkEnd}.',
    ),
    furtherBrowserSDKInfo: s__(
      `ProductAnalytics|For more information, see the %{linkStart}docs%{linkEnd}.`,
    ),
  },
  BROWSER_SDK_DOCS_URL: helpPagePath('user/product_analytics/instrumentation/browser_sdk', {
    anchor: 'browser-sdk-initialization-options',
  }),
  INSTALL_NPM_PACKAGE,
  IMPORT_NPM_PACKAGE,
  INIT_TRACKING,
  HTML_SCRIPT_SETUP,
};
</script>

<template>
  <div>
    <section>
      <p>{{ $options.i18n.instrumentAppDescription }}</p>

      <section class="gl-mb-6" data-testid="npm-instrumentation-instructions">
        <h5 class="gl-mb-5">{{ $options.i18n.jsModuleTitle }}</h5>

        <strong class="gl-block gl-mb-3">{{ $options.i18n.addNpmPackage }}</strong>
        <pre class="gl-mb-5">{{ $options.INSTALL_NPM_PACKAGE }}</pre>
        <strong class="gl-block gl-mt-5 gl-mb-3">{{ $options.i18n.importNpmPackage }}</strong>
        <pre class="gl-mb-5">{{ $options.IMPORT_NPM_PACKAGE }}</pre>
        <strong class="gl-block gl-mt-5 gl-mb-3">{{ $options.i18n.initNpmPackage }}</strong>
        <pre class="gl-mb-5"><gl-sprintf :message="$options.INIT_TRACKING">
          <template #appId><span>{{ trackingKey }}</span></template>
          <template #host><span>{{ collectorHost }}</span></template>
        </gl-sprintf></pre>
      </section>

      <section class="gl-mb-6" data-testid="html-instrumentation-instructions">
        <h5 class="gl-mb-5 gl-w-full">{{ $options.i18n.htmlScriptTag }}</h5>
        <strong class="gl-block gl-mb-3">{{ $options.i18n.htmlScriptTagDescription }}</strong>
        <pre class="gl-mb-5"><gl-sprintf :message="$options.HTML_SCRIPT_SETUP">
          <template #appId><span>{{ trackingKey }}</span></template>
          <template #host><span>{{ collectorHost }}</span></template>
        </gl-sprintf></pre>
      </section>
    </section>

    <p>
      <gl-sprintf
        :message="$options.i18n.furtherBrowserSDKInfo"
        data-testid="further-browser-sdk-info"
      >
        <template #link="{ content }">
          <gl-link :href="$options.BROWSER_SDK_DOCS_URL">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <p>
      <gl-sprintf :message="$options.i18n.summaryText" data-testid="summary-text">
        <template #link="{ content }">
          <gl-link :href="dashboardsPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
  </div>
</template>
