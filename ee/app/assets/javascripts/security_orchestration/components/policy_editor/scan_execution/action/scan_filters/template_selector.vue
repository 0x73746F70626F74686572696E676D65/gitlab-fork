<script>
import { GlCollapsibleListbox, GlIcon, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { DEFAULT_TEMPLATE, LATEST_TEMPLATE } from './constants';

export default {
  i18n: {
    label: s__('SecurityOrchestration|Security job template'),
    defaultTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The default template is stable, but may not have all the features of the latest template.',
    ),
    latestTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The latest edition may introduce breaking changes.',
    ),
  },
  components: {
    GlCollapsibleListbox,
    GlIcon,
    SectionLayout,
  },
  directives: {
    GlTooltip,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: DEFAULT_TEMPLATE,
    },
  },
  computed: {
    availableOptions() {
      return [
        { text: s__('SecurityOrchestration|latest'), value: LATEST_TEMPLATE },
        { text: s__('SecurityOrchestration|default'), value: DEFAULT_TEMPLATE },
      ];
    },
    tooltipMessage() {
      return this.selected === LATEST_TEMPLATE
        ? this.$options.i18n.latestTemplateInformation
        : this.$options.i18n.defaultTemplateInformation;
    },
  },
  methods: {
    toggleValue(value) {
      if (value === LATEST_TEMPLATE) {
        this.$emit('input', { template: value });
      } else {
        this.$emit('remove');
      }
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-white"
    content-classes="gl-justify-content-space-between"
    :show-remove-button="false"
  >
    <template #selector>
      <label class="gl-mb-0 gl-mr-4" for="policy-template" :title="$options.i18n.label">
        {{ $options.i18n.label }}
      </label>
    </template>

    <template #content>
      <div class="gl-display-flex gl-flex-grow-2 gl-align-items-center">
        <gl-collapsible-listbox
          id="policy-template"
          :items="availableOptions"
          :selected="selected"
          @select="toggleValue"
        />
        <gl-icon
          v-gl-tooltip
          name="question-o"
          :title="tooltipMessage"
          class="gl-text-blue-600 gl-ml-3"
        />
      </div>
    </template>
  </section-layout>
</template>
