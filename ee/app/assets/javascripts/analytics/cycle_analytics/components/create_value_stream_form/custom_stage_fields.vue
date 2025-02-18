<script>
import { GlAlert, GlFormGroup, GlFormInput } from '@gitlab/ui';
import { isLabelEvent, getLabelEventsIdentifiers } from '../../utils';
import { i18n } from './constants';
import CustomStageEventField from './custom_stage_event_field.vue';
import CustomStageEventLabelField from './custom_stage_event_label_field.vue';
import StageFieldActions from './stage_field_actions.vue';
import { startEventOptions, endEventOptions } from './utils';

export default {
  name: 'CustomStageFields',
  components: {
    GlAlert,
    GlFormGroup,
    GlFormInput,
    CustomStageEventField,
    CustomStageEventLabelField,
    StageFieldActions,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    stageLabel: {
      type: String,
      required: true,
    },
    totalStages: {
      type: Number,
      required: true,
    },
    stage: {
      type: Object,
      required: true,
    },
    errors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    stageEvents: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      labelEvents: getLabelEventsIdentifiers(this.stageEvents),
      formError: '',
    };
  },
  computed: {
    startEvents() {
      return startEventOptions(this.stageEvents);
    },
    endEvents() {
      return endEventOptions(this.stageEvents, this.stage.startEventIdentifier);
    },
    hasStartEvent() {
      return this.stage.startEventIdentifier;
    },
    startEventRequiresLabel() {
      return isLabelEvent(this.labelEvents, this.stage.startEventIdentifier);
    },
    endEventRequiresLabel() {
      return isLabelEvent(this.labelEvents, this.stage.endEventIdentifier);
    },
    hasMultipleStages() {
      return this.totalStages > 1;
    },
  },
  methods: {
    onSelectLabel(field, event) {
      const { id: value = null } = event;
      this.$emit('input', { field, value });
    },
    hasFieldErrors(key) {
      return !Object.keys(this.errors).length || this.errors[key]?.length < 1;
    },
    fieldErrorMessage(key) {
      return this.errors[key]?.join('\n');
    },
    setFormError(message = '') {
      this.formError = message;
    },
  },
  i18n,
};
</script>
<template>
  <div data-testid="value-stream-stage-fields">
    <gl-alert v-if="formError" class="gl-mb-4" variant="danger" @dismiss="setFormError">
      {{ formError }}
    </gl-alert>
    <div class="gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row">
      <div class="gl-flex-grow-1 gl-mr-2">
        <gl-form-group
          :label="stageLabel"
          :state="hasFieldErrors('name')"
          :invalid-feedback="fieldErrorMessage('name')"
          :data-testid="`custom-stage-name-${index}`"
        >
          <!-- eslint-disable vue/no-mutating-props -->
          <gl-form-input
            v-model.trim="stage.name"
            :name="`custom-stage-name-${index}`"
            :placeholder="$options.i18n.FORM_FIELD_STAGE_NAME_PLACEHOLDER"
            required
            @input="$emit('input', { field: 'name', value: $event })"
          />
          <!-- eslint-enable vue/no-mutating-props -->
        </gl-form-group>
        <div class="gl-display-flex gl-justify-content-between gl-mt-3">
          <custom-stage-event-field
            event-type="start-event"
            :index="index"
            :field-label="$options.i18n.FORM_FIELD_START_EVENT"
            :default-dropdown-text="$options.i18n.SELECT_START_EVENT"
            :initial-value="stage.startEventIdentifier"
            :events-list="startEvents"
            :identifier-error="fieldErrorMessage('startEventIdentifier')"
            :has-identifier-error="hasFieldErrors('startEventIdentifier')"
            @update-identifier="$emit('input', { field: 'startEventIdentifier', value: $event })"
          />
          <custom-stage-event-label-field
            event-type="start-event"
            :index="index"
            :selected-label-id="stage.startEventLabelId"
            :field-label="$options.i18n.FORM_FIELD_START_EVENT_LABEL"
            :requires-label="startEventRequiresLabel"
            :label-error="fieldErrorMessage('startEventLabelId')"
            :has-label-error="hasFieldErrors('startEventLabelId')"
            @update-label="onSelectLabel('startEventLabelId', $event)"
            @error="setFormError"
          />
        </div>
        <div class="gl-display-flex gl-justify-content-between">
          <custom-stage-event-field
            event-type="end-event"
            :index="index"
            :disabled="!hasStartEvent"
            :field-label="$options.i18n.FORM_FIELD_END_EVENT"
            :default-dropdown-text="$options.i18n.SELECT_END_EVENT"
            :initial-value="stage.endEventIdentifier"
            :events-list="endEvents"
            :identifier-error="fieldErrorMessage('endEventIdentifier')"
            :has-identifier-error="hasFieldErrors('endEventIdentifier')"
            @update-identifier="$emit('input', { field: 'endEventIdentifier', value: $event })"
          />
          <custom-stage-event-label-field
            event-type="end-event"
            :index="index"
            :selected-label-id="stage.endEventLabelId"
            :field-label="$options.i18n.FORM_FIELD_END_EVENT_LABEL"
            :requires-label="endEventRequiresLabel"
            :label-error="fieldErrorMessage('endEventLabelId')"
            :has-label-error="hasFieldErrors('endEventLabelId')"
            @update-label="onSelectLabel('endEventLabelId', $event)"
            @error="setFormError"
          />
        </div>
      </div>
      <stage-field-actions
        v-if="hasMultipleStages"
        class="gl-mt-0 gl-sm-mt-6!"
        :index="index"
        :stage-count="totalStages"
        :can-remove="true"
        @move="$emit('move', $event)"
        @remove="$emit('remove', $event)"
      />
    </div>
  </div>
</template>
