<script>
import { GlAlert, GlButton, GlForm, GlFormInput, GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { cloneDeep, uniqueId } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { filterStagesByHiddenStatus } from '~/analytics/cycle_analytics/utils';
import { swapArrayItems } from '~/lib/utils/array_utility';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  STAGE_SORT_DIRECTION,
  i18n,
  defaultCustomStageFields,
  PRESET_OPTIONS,
  PRESET_OPTIONS_DEFAULT,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';
import CustomStageFields from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_fields.vue';
import DefaultStageFields from 'ee/analytics/cycle_analytics/components/create_value_stream_form/default_stage_fields.vue';
import {
  validateValueStreamName,
  cleanStageName,
  validateStage,
  formatStageDataForSubmission,
  hasDirtyStage,
} from 'ee/analytics/cycle_analytics/components/create_value_stream_form/utils';
import ValueStreamFormContentHeader from './value_stream_form_content_header.vue';

const initializeStageErrors = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) =>
  selectedPreset === PRESET_OPTIONS_DEFAULT ? defaultStageConfig.map(() => ({})) : [{}];

const initializeStages = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) => {
  const stages =
    selectedPreset === PRESET_OPTIONS_DEFAULT
      ? defaultStageConfig
      : [{ ...defaultCustomStageFields }];
  return stages.map((stage) => ({ ...stage, transitionKey: uniqueId('stage-') }));
};

const initializeEditingStages = (stages = []) =>
  filterStagesByHiddenStatus(cloneDeep(stages), false).map((stage) => ({
    ...stage,
    transitionKey: uniqueId(`stage-${stage.name}-`),
  }));

export default {
  name: 'ValueStreamFormContent',
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormGroup,
    GlFormRadioGroup,
    DefaultStageFields,
    CustomStageFields,
    ValueStreamFormContentHeader,
  },
  mixins: [Tracking.mixin()],
  props: {
    initialData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    initialPreset: {
      type: String,
      required: false,
      default: PRESET_OPTIONS_DEFAULT,
    },
    initialFormErrors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    defaultStageConfig: {
      type: Array,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    valueStreamPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    const {
      defaultStageConfig = [],
      initialData: { name: initialName, stages: initialStages = [] },
      initialFormErrors,
      initialPreset,
    } = this;
    const { name: nameErrors = [], stages: stageErrors = [{}] } = initialFormErrors;
    const additionalFields = {
      stages: this.isEditing
        ? initializeEditingStages(initialStages)
        : initializeStages(defaultStageConfig, initialPreset),
      stageErrors:
        cloneDeep(stageErrors) || initializeStageErrors(defaultStageConfig, initialPreset),
    };

    return {
      hiddenStages: filterStagesByHiddenStatus(initialStages),
      selectedPreset: initialPreset,
      presetOptions: PRESET_OPTIONS,
      name: initialName,
      nameErrors,
      stageErrors,
      showSubmitError: false,
      isRedirecting: false,
      ...additionalFields,
    };
  },
  computed: {
    ...mapState({
      isCreating: 'isCreatingValueStream',
      isSaving: 'isEditingValueStream',
      isFetchingGroupLabels: 'isFetchingGroupLabels',
      formEvents: 'formEvents',
      defaultGroupLabels: 'defaultGroupLabels',
    }),
    isValueStreamNameValid() {
      return !this.nameErrors?.length;
    },
    invalidNameFeedback() {
      return this.nameErrors?.length ? this.nameErrors.join('\n\n') : null;
    },
    hasInitialFormErrors() {
      const { initialFormErrors } = this;
      return Boolean(Object.keys(initialFormErrors).length);
    },
    isSubmitting() {
      return this.isCreating || this.isSaving;
    },
    hasFormErrors() {
      return Boolean(
        this.nameErrors.length || this.stageErrors.some((obj) => Object.keys(obj).length),
      );
    },
    isDirtyEditing() {
      return (
        this.isEditing &&
        (this.hasDirtyName(this.name, this.initialData.name) ||
          hasDirtyStage(this.stages, this.initialData.stages))
      );
    },
    canRestore() {
      return this.hiddenStages.length || this.isDirtyEditing;
    },
    currentValueStreamStageNames() {
      return this.stages.map(({ name }) => cleanStageName(name));
    },
  },
  methods: {
    ...mapActions(['createValueStream', 'updateValueStream']),
    onSubmit() {
      this.showSubmitError = false;
      this.validate();
      if (this.hasFormErrors) return false;

      let req = this.createValueStream;
      let params = {
        name: this.name,
        stages: formatStageDataForSubmission(this.stages, this.isEditing),
      };
      if (this.isEditing) {
        req = this.updateValueStream;
        params = {
          ...params,
          id: this.initialData.id,
        };
      }

      return req(params).then(() => {
        if (this.hasInitialFormErrors) {
          const { name: nameErrors = [], stages: stageErrors = [{}] } = this.initialFormErrors;

          this.isRedirecting = false;
          this.nameErrors = nameErrors;
          this.stageErrors = stageErrors;
          this.showSubmitError = true;

          return;
        }

        const msg = this.isEditing
          ? this.$options.i18n.FORM_EDITED
          : this.$options.i18n.FORM_CREATED;
        this.$toast.show(sprintf(msg, { name: this.name }));
        this.nameErrors = [];
        this.stageErrors = initializeStageErrors(this.defaultStageConfig, this.selectedPreset);
        this.track('submit_form', {
          label: this.isEditing ? 'edit_value_stream' : 'create_value_stream',
        });

        if (!this.isEditing && this.valueStreamPath) {
          this.isRedirecting = true;

          visitUrl(this.valueStreamPath);
        }
      });
    },
    stageGroupLabel(index) {
      return sprintf(this.$options.i18n.STAGE_INDEX, { index: index + 1 });
    },
    recoverStageTitle(name) {
      return sprintf(this.$options.i18n.HIDDEN_DEFAULT_STAGE, { name });
    },
    hasDirtyName(current, original) {
      return current.trim().toLowerCase() !== original.trim().toLowerCase();
    },
    validateStages() {
      return this.stages.map((stage) => validateStage(stage, this.currentValueStreamStageNames));
    },
    validate() {
      const { name } = this;
      this.nameErrors = validateValueStreamName({ name });
      this.stageErrors = this.validateStages();
    },
    moveItem(arr, index, direction) {
      return direction === STAGE_SORT_DIRECTION.UP
        ? swapArrayItems(arr, index - 1, index)
        : swapArrayItems(arr, index, index + 1);
    },
    handleMove({ index, direction }) {
      const newStages = this.moveItem(this.stages, index, direction);
      const newErrors = this.moveItem(this.stageErrors, index, direction);
      this.stages = cloneDeep(newStages);
      this.stageErrors = cloneDeep(newErrors);
    },
    validateStageFields(index) {
      const copy = [...this.stageErrors];
      copy[index] = validateStage(this.stages[index]);
      this.stageErrors = copy;
    },
    fieldErrors(index) {
      return this.stageErrors && this.stageErrors[index] ? this.stageErrors[index] : {};
    },
    onHide(index) {
      const target = this.stages[index];
      this.stages = [...this.stages.filter((_, i) => i !== index)];
      this.hiddenStages = [...this.hiddenStages, target];
    },
    onRemove(index) {
      const newErrors = this.stageErrors.filter((_, idx) => idx !== index);
      const newStages = this.stages.filter((_, idx) => idx !== index);
      this.stages = [...newStages];
      this.stageErrors = [...newErrors];
    },
    onRestore(hiddenStageIndex) {
      const target = this.hiddenStages[hiddenStageIndex];
      this.hiddenStages = [...this.hiddenStages.filter((_, i) => i !== hiddenStageIndex)];
      this.stages = [
        ...this.stages,
        { ...target, transitionKey: uniqueId(`stage-${target.name}-`) },
      ];
    },
    lastStage() {
      const stages = this.$refs.formStages;
      return stages[stages.length - 1];
    },
    async scrollToLastStage() {
      await this.$nextTick();
      // Scroll to the new stage we have added
      this.lastStage().focus();
      this.lastStage().scrollIntoView({ behavior: 'smooth' });
    },
    addNewStage() {
      // validate previous stages only and add a new stage
      this.validate();
      this.stages = [
        ...this.stages,
        { ...defaultCustomStageFields, transitionKey: uniqueId('stage-') },
      ];
      this.stageErrors = [...this.stageErrors, {}];
    },
    onAddStage() {
      this.addNewStage();
      this.scrollToLastStage();
    },
    onFieldInput(activeStageIndex, { field, value }) {
      const updatedStage = { ...this.stages[activeStageIndex], [field]: value };
      const copy = [...this.stages];
      copy[activeStageIndex] = updatedStage;
      this.stages = copy;
    },
    resetAllFieldsToDefault() {
      this.stages = initializeStages(this.defaultStageConfig, this.selectedPreset);
      this.stageErrors = initializeStageErrors(this.defaultStageConfig, this.selectedPreset);
    },
    handleResetDefaults() {
      if (this.isEditing) {
        const {
          initialData: { name: initialName, stages: initialStages },
        } = this;
        this.name = initialName;
        this.nameErrors = [];
        this.stages = initializeStages(initialStages);
        this.stageErrors = [{}];
      } else {
        this.resetAllFieldsToDefault();
      }
    },
    onSelectPreset() {
      if (this.selectedPreset === PRESET_OPTIONS_DEFAULT) {
        this.handleResetDefaults();
      } else {
        this.resetAllFieldsToDefault();
      }
    },
    restoreActionTestId(index) {
      return `stage-action-restore-${index}`;
    },
  },
  i18n,
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showSubmitError"
      variant="danger"
      class="gl-mb-3"
      @dismiss="showSubmitError = false"
    >
      {{ $options.i18n.SUBMIT_FAILED }}
    </gl-alert>
    <value-stream-form-content-header
      class="gl-mb-6"
      :is-editing="isEditing"
      :is-loading="isSubmitting || isRedirecting"
      :value-stream-path="valueStreamPath"
      @clickedPrimaryAction="onSubmit"
    />
    <gl-form>
      <gl-form-group
        data-testid="create-value-stream-name"
        label-for="create-value-stream-name"
        :label="$options.i18n.FORM_FIELD_NAME_LABEL"
        :invalid-feedback="invalidNameFeedback"
        :state="isValueStreamNameValid"
      >
        <div class="gl-display-flex gl-justify-content-space-between">
          <gl-form-input
            id="create-value-stream-name"
            v-model.trim="name"
            name="create-value-stream-name"
            data-testid="create-value-stream-name-input"
            :placeholder="$options.i18n.FORM_FIELD_NAME_PLACEHOLDER"
            :state="isValueStreamNameValid"
            required
          />
          <transition name="fade">
            <gl-button
              v-if="canRestore"
              data-testid="vsa-reset-button"
              class="gl-ml-3"
              variant="link"
              @click="handleResetDefaults"
              >{{ $options.i18n.RESTORE_DEFAULTS }}</gl-button
            >
          </transition>
        </div>
      </gl-form-group>
      <gl-form-radio-group
        v-if="!isEditing"
        v-model="selectedPreset"
        class="gl-mb-4"
        data-testid="vsa-preset-selector"
        :options="presetOptions"
        name="preset"
        @input="onSelectPreset"
      />
      <div data-testid="extended-form-fields">
        <transition-group name="stage-list" tag="div">
          <div
            v-for="(stage, activeStageIndex) in stages"
            ref="formStages"
            :key="stage.id || stage.transitionKey"
          >
            <hr class="gl-my-5" />
            <custom-stage-fields
              v-if="stage.custom"
              :stage-label="stageGroupLabel(activeStageIndex)"
              :stage="stage"
              :stage-events="formEvents"
              :index="activeStageIndex"
              :total-stages="stages.length"
              :errors="fieldErrors(activeStageIndex)"
              :default-group-labels="defaultGroupLabels"
              @move="handleMove"
              @remove="onRemove"
              @input="onFieldInput(activeStageIndex, $event)"
            />
            <default-stage-fields
              v-else
              :stage-label="stageGroupLabel(activeStageIndex)"
              :stage="stage"
              :stage-events="formEvents"
              :index="activeStageIndex"
              :total-stages="stages.length"
              :errors="fieldErrors(activeStageIndex)"
              @move="handleMove"
              @hide="onHide"
              @input="validateStageFields(activeStageIndex)"
            />
          </div>
        </transition-group>
        <div>
          <hr class="gl-mt-2 gl-mb-5" />
          <gl-button
            data-testid="vsa-add-stage-button"
            category="secondary"
            variant="confirm"
            icon="plus"
            @click="onAddStage"
            >{{ $options.i18n.BTN_ADD_ANOTHER_STAGE }}</gl-button
          >
        </div>
        <div v-if="hiddenStages.length">
          <hr />
          <gl-form-group
            v-for="(stage, hiddenStageIndex) in hiddenStages"
            :key="stage.id"
            data-testid="vsa-hidden-stage"
          >
            <span class="gl-m-0 gl-align-middle gl-mr-3 gl-font-bold">{{
              recoverStageTitle(stage.name)
            }}</span>
            <gl-button
              variant="link"
              :data-testid="restoreActionTestId(hiddenStageIndex)"
              @click="onRestore(hiddenStageIndex)"
              >{{ $options.i18n.RESTORE_HIDDEN_STAGE }}</gl-button
            >
          </gl-form-group>
        </div>
      </div>
    </gl-form>
  </div>
</template>
