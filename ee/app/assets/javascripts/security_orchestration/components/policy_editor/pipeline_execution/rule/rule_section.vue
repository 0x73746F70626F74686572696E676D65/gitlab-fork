<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  i18n: {
    conditionText: s__(
      'SecurityOrchestration|Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
    ),
    helpPageLink: helpPagePath('user/application_security/policies/pipeline_execution_policies'),
  },
  components: {
    GlLink,
    GlSprintf,
  },
};
</script>

<template>
  <div
    class="gl-display-flex gl-flex-direction-column gl-lg-flex-direction-row gl-gap-3 security-policies-bg-gray-10 gl-rounded-base gl-p-5"
  >
    <gl-sprintf :message="$options.i18n.conditionText">
      <template #link="{ content }">
        <gl-link :href="$options.i18n.helpPageLink" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>
