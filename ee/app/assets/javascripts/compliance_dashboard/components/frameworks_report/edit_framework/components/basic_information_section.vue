<script>
import {
  GlAlert,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlLink,
  GlSprintf,
  GlButton,
  GlPopover,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { helpPagePath } from '~/helpers/help_page_helper';
import ColorPicker from '~/vue_shared/components/color_picker/color_picker.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS as DEBOUNCE_DELAY } from '~/lib/utils/constants';
import { validateHexColor } from '~/lib/utils/color_utils';
import {
  validatePipelineConfirmationFormat,
  fetchPipelineConfigurationFileExists,
} from 'ee/groups/settings/compliance_frameworks/utils';
import { maxNameLength, i18n } from '../constants';
import EditSection from './edit_section.vue';

export default {
  components: {
    ColorPicker,
    EditSection,

    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlSprintf,
    GlPopover,
    GlAlert,
    GlButton,
  },

  inject: [
    'featurePipelineMaintenanceModeEnabled',
    'migratePipelineToPolicyPath',
    'pipelineConfigurationFullPathEnabled',
    'pipelineConfigurationEnabled',
    'pipelineExecutionPolicyPath',
  ],
  props: {
    value: {
      type: Object,
      required: true,
    },
    expandable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data() {
    return {
      formData: JSON.parse(JSON.stringify(this.value)),
      maintenanceModeDismissed: false,
      pipelineConfigurationFileExists: true,
    };
  },

  computed: {
    pipelineConfigurationFeedbackMessage() {
      if (!this.isValidPipelineConfigurationFormat) {
        return this.$options.i18n.pipelineConfigurationInputInvalidFormat;
      }

      return this.$options.i18n.pipelineConfigurationInputUnknownFile;
    },

    compliancePipelineConfigurationHelpPath() {
      return helpPagePath('user/group/compliance_frameworks.md', {
        anchor: 'example-configuration',
      });
    },

    isValidColor() {
      return validateHexColor(this.formData.color);
    },

    isValidName() {
      if (this.formData.name === null) {
        return null;
      }

      if (this.formData.name.length > maxNameLength) {
        return false;
      }

      return Boolean(this.formData.name);
    },

    isValidDescription() {
      if (this.formData.description === null) {
        return null;
      }

      return Boolean(this.formData.description);
    },

    isValidPipelineConfiguration() {
      if (!this.formData.pipelineConfigurationFullPath) {
        return null;
      }

      return this.isValidPipelineConfigurationFormat && this.pipelineConfigurationFileExists;
    },

    isValidPipelineConfigurationFormat() {
      return validatePipelineConfirmationFormat(this.formData.pipelineConfigurationFullPath);
    },

    isValid() {
      return (
        this.isValidName &&
        this.isValidDescription &&
        this.isValidColor &&
        this.isValidPipelineConfiguration !== false
      );
    },
    showMaintenanceModeAlert() {
      return this.featurePipelineMaintenanceModeEnabled && !this.maintenanceModeDismissed;
    },
  },

  watch: {
    formData: {
      handler(newValue) {
        this.$emit('input', newValue);
      },
      deep: true,
    },
    'formData.pipelineConfigurationFullPath': {
      handler(path) {
        if (path) {
          this.validatePipelineInput(path);
        }
      },
    },
    isValid: {
      handler() {
        this.$emit('valid', this.isValid);
      },
      immediate: true,
    },
  },

  methods: {
    async validatePipelineConfigurationPath(path) {
      this.pipelineConfigurationFileExists = await fetchPipelineConfigurationFileExists(path);
    },

    validatePipelineInput: debounce(function debounceValidation(path) {
      this.validatePipelineConfigurationPath(path);
    }, DEBOUNCE_DELAY),

    handleOnDismissMaintenanceMode() {
      this.maintenanceModeDismissed = true;
    },
  },

  i18n,
  disabledPipelineConfigurationInputPopoverTarget:
    'disabled-pipeline-configuration-input-popover-target',
};
</script>
<template>
  <edit-section
    :title="$options.i18n.basicInformation"
    :description="$options.i18n.basicInformationDetails"
    :expandable="expandable"
    :initially-expanded="expandable"
  >
    <gl-form-group
      :label="$options.i18n.titleInputLabel"
      label-for="name-input"
      :invalid-feedback="$options.i18n.titleInputInvalid"
      :state="isValidName"
      data-testid="name-input-group"
    >
      <gl-form-input
        id="name-input"
        v-model="formData.name"
        name="name"
        :state="isValidName"
        data-testid="name-input"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionInputLabel"
      label-for="description-input"
      :invalid-feedback="$options.i18n.descriptionInputInvalid"
      :state="isValidDescription"
      data-testid="description-input-group"
    >
      <gl-form-input
        id="description-input"
        v-model="formData.description"
        name="description"
        :state="isValidDescription"
        data-testid="description-input"
      />
    </gl-form-group>
    <color-picker
      v-model="formData.color"
      :label="$options.i18n.colorInputLabel"
      :state="isValidColor"
    />
    <gl-form-group
      v-if="pipelineConfigurationFullPathEnabled && pipelineConfigurationEnabled"
      :label="$options.i18n.pipelineConfigurationInputLabel"
      label-for="pipeline-configuration-input"
      :invalid-feedback="pipelineConfigurationFeedbackMessage"
      :state="isValidPipelineConfiguration"
      data-testid="pipeline-configuration-input-group"
    >
      <template #description>
        <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDescription">
          <template #code="{ content }">
            <code>{{ content }}</code>
          </template>

          <template #link="{ content }">
            <gl-link :href="compliancePipelineConfigurationHelpPath" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </template>

      <gl-alert
        v-if="showMaintenanceModeAlert"
        variant="warning"
        class="gl-my-3"
        data-testid="maintenance-mode-alert"
        :dismissible="true"
        :title="$options.i18n.deprecationWarning.title"
        @dismiss="handleOnDismissMaintenanceMode"
      >
        <p>
          <gl-sprintf :message="$options.i18n.deprecationWarning.message">
            <template #link="{ content }">
              <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </p>

        <gl-sprintf :message="$options.i18n.deprecationWarning.details">
          <template #link="{ content }">
            <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>

        <template #actions>
          <gl-button
            category="primary"
            variant="confirm"
            :href="migratePipelineToPolicyPath"
            target="_blank"
          >
            {{ $options.i18n.deprecationWarning.migratePipelineToPolicy }}
          </gl-button>

          <gl-button class="gl-ml-5" @click="handleOnDismissMaintenanceMode">
            {{ $options.i18n.deprecationWarning.dismiss }}
          </gl-button>
        </template>
      </gl-alert>

      <gl-form-input
        id="pipeline-configuration-input"
        v-model="formData.pipelineConfigurationFullPath"
        name="pipeline_configuration_full_path"
        :state="isValidPipelineConfiguration"
        data-testid="pipeline-configuration-input"
      />
    </gl-form-group>
    <template v-if="!pipelineConfigurationEnabled">
      <gl-form-group
        id="disabled-pipeline-configuration-input-group"
        :label="$options.i18n.pipelineConfigurationInputLabel"
        label-for="disabled-pipeline-configuration-input"
        data-testid="disabled-pipeline-configuration-input-group"
      >
        <div :id="$options.disabledPipelineConfigurationInputPopoverTarget" tabindex="0">
          <gl-form-input
            id="disabled-pipeline-configuration-input"
            disabled
            data-testid="disabled-pipeline-configuration-input"
          />
        </div>
      </gl-form-group>
      <gl-popover
        :title="$options.i18n.pipelineConfigurationInputDisabledPopoverTitle"
        show-close-button
        :target="$options.disabledPipelineConfigurationInputPopoverTarget"
        data-testid="disabled-pipeline-configuration-input-popover"
      >
        <p class="gl-mb-0">
          <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDisabledPopoverContent">
            <template #link="{ content }">
              <gl-link
                :href="$options.i18n.pipelineConfigurationInputDisabledPopoverLink"
                target="_blank"
                class="gl-font-sm"
              >
                {{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </p>
      </gl-popover>
    </template>
    <gl-form-checkbox v-model="formData.default" name="default">
      <span class="gl-font-bold">{{ $options.i18n.setAsDefault }}</span>
      <template #help>
        <div>
          {{ $options.i18n.setAsDefaultDetails }}
        </div>
        <div>
          {{ $options.i18n.setAsDefaultOnlyOne }}
        </div>
      </template>
    </gl-form-checkbox>
  </edit-section>
</template>
