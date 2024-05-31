<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import SectionLayout from '../../section_layout.vue';

export default {
  documentationLink: helpPagePath('user/application_security/policies/scan-result-policies', {
    anchor: 'example-bot-messages',
  }),
  i18n: {
    contentText: s__(
      'SecurityOrchestration|%{boldStart}Send a bot message%{boldEnd} as comment to merge request creator.',
    ),
    linkText: s__('SecurityOrchestration|What does an example message look like?'),
  },
  name: 'BotCommentAction',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    SectionLayout,
  },
};
</script>

<template>
  <section-layout @remove="$emit('remove')">
    <template #content>
      <div class="gl-flex-direction-column gl-mt-3">
        <gl-sprintf :message="$options.i18n.contentText">
          <template #bold="{ content }">
            <b>{{ content }}</b>
          </template>
        </gl-sprintf>
        <gl-link
          class="gl-block gl-mt-5 gl-min-w-fit"
          :href="$options.documentationLink"
          target="_blank"
        >
          <gl-icon name="information-o" />
          {{ $options.i18n.linkText }}
        </gl-link>
      </div>
    </template>
  </section-layout>
</template>
