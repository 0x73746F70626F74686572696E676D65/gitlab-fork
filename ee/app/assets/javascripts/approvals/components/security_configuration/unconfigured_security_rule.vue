<script>
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import RuleName from 'ee/approvals/components/rules/rule_name.vue';

export default {
  components: {
    GlButton,
    GlLink,
    GlSprintf,
    RuleName,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <!-- Suggested approval rule creation row -->
  <td class="js-name" colspan="5">
    <div class="gl-display-flex gl-gap-5">
      <div class="gl-w-full">
        <rule-name class="gl-text-left!" :name="rule.name" />

        <div class="gl-text-gray-500 gl-text-left!">
          <gl-sprintf :message="rule.description">
            <template #link="{ content }">
              <gl-link :href="rule.docsPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </div>
      </div>

      <div>
        <gl-button @click="$emit('enable')">
          {{ __('Enable') }}
        </gl-button>
      </div>
    </div>
  </td>
</template>
