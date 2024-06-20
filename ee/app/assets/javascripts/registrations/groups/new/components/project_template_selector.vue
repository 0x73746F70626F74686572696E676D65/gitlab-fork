<script>
import {
  GlFormGroup,
  GlFormInput,
  GlTooltipDirective,
  GlIcon,
  GlButton,
  GlCollapsibleListbox,
} from '@gitlab/ui';

import EXPRESS_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/logos/express.svg?url';
import DOTNET_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/third-party-logos/dotnet.svg?url';
import GITLAB_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg?url';
import LARAVEL_LOGO_SVG_URL from '@gitlab/svgs/dist/illustrations/logos/laravel.svg?url';
import { s__ } from '~/locale';
import DEFAULT_PROJECT_TEMPLATES from 'ee/projects/default_project_templates';
import { DEFAULT_SELECTED_LABEL } from '../constants';

export default {
  components: {
    GlFormGroup,
    GlFormInput,
    GlButton,
    GlIcon,
    GlCollapsibleListbox,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedTemplateName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      selected: this.selectedTemplateName,
      selectedLogo: null,
      selectedLabel: DEFAULT_SELECTED_LABEL,
      toggleIconName: 'chevron-down',
    };
  },
  computed: {
    items() {
      return [
        {
          value: 'express',
          text: DEFAULT_PROJECT_TEMPLATES.express.text,
          logoSrc: EXPRESS_LOGO_SVG_URL,
        },
        {
          value: 'dotnetcore',
          text: DEFAULT_PROJECT_TEMPLATES.dotnetcore.text,
          logoSrc: DOTNET_LOGO_SVG_URL,
        },
        {
          value: 'plainhtml',
          text: DEFAULT_PROJECT_TEMPLATES.plainhtml.text,
          logoSrc: GITLAB_LOGO_SVG_URL,
        },
        {
          value: 'laravel',
          text: DEFAULT_PROJECT_TEMPLATES.laravel.text,
          logoSrc: LARAVEL_LOGO_SVG_URL,
        },
      ];
    },
  },
  mounted() {
    if (this.selectedTemplateName.length > 0) {
      this.selectTemplate(this.selectedTemplateName);
    }
  },
  methods: {
    selectTemplate(value) {
      this.$emit('select', value);

      const selectedItem = this.items.find((item) => item.value === value);

      this.selectedLogo = selectedItem.logoSrc;
      this.selectedLabel = selectedItem.text;
    },
    resetTemplate() {
      this.$emit('select', '');

      this.selected = '';
      this.selectedLogo = null;
      this.selectedLabel = DEFAULT_SELECTED_LABEL;
    },
    showList() {
      this.toggleIconName = 'chevron-up';
    },
    hideList() {
      this.toggleIconName = 'chevron-down';
    },
  },
  i18n: {
    templateNameLabel: s__('ProjectsNew|Select a template'),
    templateNameOptional: s__('ProjectsNew|(optional)'),
    templateNameLabelDescription: s__(
      'ProjectsNew|Get started with one of our popular project templates.',
    ),
    templateNameTooltip: s__('ProjectsNew|More templates are available after sign-up.'),
  },
};
</script>
<template>
  <gl-form-group
    class="col-sm-12"
    optional
    :label="$options.i18n.templateNameLabel"
    :optional-text="$options.i18n.templateNameOptional"
  >
    <template #label-description>
      {{ $options.i18n.templateNameLabelDescription }}

      <gl-icon
        v-gl-tooltip
        class="gl-text-blue-500"
        name="question-o"
        :title="$options.i18n.templateNameTooltip"
      />
    </template>

    <gl-collapsible-listbox
      v-model="selected"
      class="gl-w-full"
      reset-button-label="Reset"
      :items="items"
      :header-text="$options.i18n.templateNameLabel"
      @select="selectTemplate"
      @reset="resetTemplate"
      @shown="showList"
      @hidden="hideList"
    >
      <template #toggle>
        <gl-button class="gl-w-full" button-text-classes="gl-w-full">
          <span class="gl-display-flex gl-justify-content-space-between">
            <span class="gl-display-flex gl-align-items-center gl-gap-2">
              <img
                v-if="selectedLogo"
                class="gl-w-5 gl-h-5"
                data-testid="selected-logo"
                :alt="selected"
                :src="selectedLogo"
              />

              {{ selectedLabel }}
            </span>

            <gl-icon :name="toggleIconName" />
          </span>
        </gl-button>
      </template>

      <template #list-item="{ item }">
        <span class="gl-display-flex gl-align-items-center gl-gap-2">
          <img class="gl-w-5 gl-h-5" :alt="item.value" :src="item.logoSrc" />
          {{ item.text }}
        </span>
      </template>
    </gl-collapsible-listbox>

    <gl-form-input hidden name="project[template_name]" autocomplete="off" :value="selected" />
  </gl-form-group>
</template>
