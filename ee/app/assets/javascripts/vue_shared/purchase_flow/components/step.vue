<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlFormGroup, GlButton } from '@gitlab/ui';
import activateNextStepMutation from 'ee/vue_shared/purchase_flow/graphql/mutations/activate_next_step.mutation.graphql';
import updateStepMutation from 'ee/vue_shared/purchase_flow/graphql/mutations/update_active_step.mutation.graphql';
import activeStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/active_step.query.graphql';
import furthestAccessedStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/furthest_accessed_step.query.graphql';
import stepListQuery from 'ee/vue_shared/purchase_flow/graphql/queries/step_list.query.graphql';
import { createAlert } from '~/alert';
import { i18n, GENERAL_ERROR_MESSAGE } from 'ee/vue_shared/purchase_flow/constants';
import StepHeader from 'ee/vue_shared/purchase_flow/components/step_header.vue';

export default {
  components: {
    GlFormGroup,
    GlButton,
    StepHeader,
  },
  props: {
    editButtonText: {
      type: String,
      required: false,
      default: i18n.edit,
    },
    stepId: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    isValid: {
      type: Boolean,
      required: true,
    },
    nextStepButtonText: {
      type: String,
      required: false,
      default: '',
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['nextStep', 'stepEdit'],
  data() {
    return {
      activeStep: {},
      furthestAccessedStep: {},
      stepList: [],
      loading: false,
    };
  },
  apollo: {
    activeStep: {
      query: activeStepQuery,
      error(error) {
        this.handleError(error);
      },
    },
    furthestAccessedStep: {
      query: furthestAccessedStepQuery,
      error(error) {
        this.handleError(error);
      },
    },
    stepList: {
      query: stepListQuery,
    },
  },
  computed: {
    isActive() {
      return this.activeStep.id === this.stepId;
    },
    isFinished() {
      // Only mark step finished if we've already navigated to it
      if (this.furthestStepIndex < 1) {
        return false;
      }

      return this.isValid && !this.isActive;
    },
    isEditable() {
      const index = this.stepList.findIndex(({ id }) => id === this.stepId);
      return this.isFinished && index < this.activeIndex;
    },
    activeIndex() {
      return this.stepList.findIndex(({ id }) => id === this.activeStep.id);
    },
    furthestStepIndex() {
      return this.stepList.findIndex(({ id }) => id === this.furthestAccessedStep.id);
    },
    shouldShowError() {
      return this.nextStepButtonText && !this.isValid && this.errorMessage;
    },
  },
  methods: {
    handleError(error) {
      createAlert({ message: GENERAL_ERROR_MESSAGE, error, captureError: true });
    },
    nextStep() {
      if (!this.isValid) {
        return;
      }
      this.loading = true;
      this.$apollo
        .mutate({
          mutation: activateNextStepMutation,
        })
        .catch((error) => {
          this.handleError(error);
        })
        .finally(() => {
          this.loading = false;
          this.$emit('nextStep');
        });
    },
    edit() {
      this.loading = true;
      this.$emit('stepEdit', this.stepId);

      return this.$apollo
        .mutate({
          mutation: updateStepMutation,
          variables: { id: this.stepId },
        })
        .catch((error) => {
          this.handleError(error);
        })
        .finally(() => {
          this.loading = false;
        });
    },
  },
};
</script>
<template>
  <div class="gl-w-full gl-pb-5 gl-border-b gl-mb-5">
    <step-header
      :edit-button-text="editButtonText"
      :title="title"
      :is-finished="isFinished"
      :is-editable="isEditable"
      @edit="edit"
    />
    <div v-show="isActive" class="gl-mt-5" data-testid="active-step-body" @keyup.enter="nextStep">
      <slot name="body" :active="isActive"></slot>
      <gl-form-group
        v-if="shouldShowError"
        :invalid-feedback="errorMessage"
        :state="isValid"
        class="gl-mb-5"
      />
      <gl-button
        v-if="nextStepButtonText"
        variant="confirm"
        category="primary"
        :disabled="!isValid"
        @click="nextStep"
      >
        {{ nextStepButtonText }}
      </gl-button>
      <slot name="footer"></slot>
    </div>
    <slot v-if="isFinished" name="summary"></slot>
  </div>
</template>
