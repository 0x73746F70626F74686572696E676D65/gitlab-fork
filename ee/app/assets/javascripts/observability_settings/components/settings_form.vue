<script>
import { GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

export default {
  components: {
    GlButton,
    GlSprintf,
    GlLink,
  },
  docsLink: `${DOCS_URL_IN_EE_DIR}/operations`,
  i18n: {
    headerText: s__('Observability|Tracing, Metrics & Logs'),
    expandBtnLabel: __('Expand'),
    subHeaderText: s__('Observability|Enable tracing, metrics, or logs on your project.'),
    introText: s__(
      'Observability|View our %{docsLink} for further instructions on how to use these features.',
    ),
    introLinkText: s__('Observability|documentation'),
  },
};
</script>

<template>
  <section class="settings no-animate">
    <div class="settings-header">
      <h4 class="settings-title js-settings-toggle js-settings-toggle-trigger-only">
        {{ $options.i18n.headerText }}
      </h4>
      <gl-button class="js-settings-toggle">{{ $options.i18n.expandBtnLabel }}</gl-button>
      <p class="gl-text-secondary">
        {{ $options.i18n.subHeaderText }}
      </p>
    </div>

    <div class="settings-content">
      <p>
        <gl-sprintf :message="$options.i18n.introText">
          <template #docsLink>
            <gl-link :href="$options.docsLink">
              <span>{{ $options.i18n.introLinkText }}</span>
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>
  </section>
</template>
