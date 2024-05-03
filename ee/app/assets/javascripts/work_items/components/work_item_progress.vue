<script>
import {
  GlForm,
  GlFormInput,
  GlFormGroup,
  GlIcon,
  GlPopover,
  GlButton,
  GlLoadingIcon,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __ } from '~/locale';
import Tracking from '~/tracking';
import {
  sprintfWorkItem,
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  WORK_ITEM_TYPE_VALUE_OBJECTIVE,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';

export default {
  inputId: 'progress-widget-input',
  minValue: 0,
  maxValue: 100,
  components: {
    GlForm,
    GlFormInput,
    GlFormGroup,
    GlIcon,
    GlPopover,
    GlButton,
    GlLoadingIcon,
  },
  mixins: [Tracking.mixin(), glFeatureFlagMixin()],
  i18n: {
    progressPopoverTitle: __('How is progress calculated?'),
    progressPopoverContent: __(
      'This field is auto-calculated based on the progress score of its direct children. You can overwrite this value but it will be replaced by the auto-calculation anytime the progress score of its direct children are updated.',
    ),
    progressTitle: __('Progress'),
    invalidMessage: __('Enter a number from 0 to 100.'),
  },
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    progress: {
      type: Number,
      required: false,
      default: undefined,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isEditing: false,
      localProgress: this.progress,
      isUpdating: false,
    };
  },
  computed: {
    placeholder() {
      return this.canUpdate && this.isEditing ? __('Enter a number') : __('None');
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_progress',
        property: `type_${this.workItemType}`,
      };
    },
    showProgressPopover() {
      return (
        this.glFeatures.okrAutomaticRollups && this.workItemType === WORK_ITEM_TYPE_VALUE_OBJECTIVE
      );
    },
    isValidProgress() {
      if (this.localProgress === '') {
        return false;
      }

      const valueAsNumber = Number(this.localProgress);

      return this.checkValidProgress(valueAsNumber);
    },
  },
  watch: {
    progress(newValue) {
      this.localProgress = newValue;
    },
  },
  methods: {
    checkValidProgress(progress) {
      return (
        Number.isInteger(progress) &&
        progress >= this.$options.minValue &&
        progress <= this.$options.maxValue
      );
    },
    updateProgress() {
      if (!this.canUpdate) return;

      if (this.localProgress === '') {
        this.cancelEditing();
        return;
      }

      const valueAsNumber = Number(this.localProgress);

      if (valueAsNumber === this.progress || !this.checkValidProgress(valueAsNumber)) {
        this.cancelEditing();
        return;
      }

      this.isUpdating = true;
      this.track('updated_progress');
      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              progressWidget: {
                currentValue: valueAsNumber,
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.localProgress = this.progress;
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
          this.isEditing = false;
        });
    },
    cancelEditing() {
      this.localProgress = this.progress;
      this.isEditing = false;
    },
  },
};
</script>

<template>
  <div data-testid="work-item-progress-wrapper">
    <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-mb-0! gl-heading-5">
        {{ $options.i18n.progressTitle }}
        <template v-if="showProgressPopover">
          <gl-icon id="okr-progress-popover-title" class="gl-text-blue-600" name="question-o" />
          <gl-popover
            triggers="hover"
            target="okr-progress-popover-title"
            placement="right"
            :title="$options.i18n.progressPopoverTitle"
            :content="$options.i18n.progressPopoverContent"
          />
        </template>
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-progress"
        category="tertiary"
        size="small"
        @click="isEditing = true"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <gl-form v-if="isEditing" data-testid="work-item-progress" @submit.prevent="updateProgress">
      <div class="gl-display-flex gl-align-items-center">
        <label for="progress-widget-input" class="gl-mb-0"
          >{{ $options.i18n.progressTitle }}
          <template v-if="showProgressPopover">
            <gl-icon id="okr-progress-popover-label" class="gl-text-blue-600" name="question-o" />
            <gl-popover
              triggers="hover"
              target="okr-progress-popover-label"
              placement="right"
              :title="$options.i18n.progressPopoverTitle"
              :content="$options.i18n.progressPopoverContent"
            />
          </template>
        </label>
        <gl-loading-icon v-if="isUpdating" size="sm" inline class="gl-ml-3" />
        <gl-button
          data-testid="apply-progress"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="updateProgress"
        >
          {{ __('Apply') }}
        </gl-button>
      </div>
      <gl-form-group :invalid-feedback="$options.i18n.invalidMessage">
        <gl-form-input
          id="progress-widget-input"
          ref="input"
          v-model="localProgress"
          autofocus
          :min="$options.minValue"
          :max="$options.maxValue"
          data-testid="work-item-progress-input"
          class="gl-hover-border-gray-200! gl-border-solid! hide-unfocused-input-decoration work-item-field-value gl-max-w-full!"
          :placeholder="placeholder"
          :state="isValidProgress"
          width="sm"
          type="number"
          @blur="updateProgress"
          @keyup.escape="cancelEditing"
        />
      </gl-form-group>
    </gl-form>
    <span v-else class="gl-my-3" data-testid="progress-displayed-value">
      {{ localProgress }}%
    </span>
  </div>
</template>
