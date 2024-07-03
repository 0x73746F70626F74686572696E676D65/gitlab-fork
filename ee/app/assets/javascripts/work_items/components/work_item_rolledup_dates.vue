<script>
import {
  GlButton,
  GlDatepicker,
  GlFormGroup,
  GlOutsideDirective as Outside,
  GlFormRadio,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { newWorkItemId } from '~/work_items/utils';
import { getDateWithUTC, newDateAsLocaleTime } from '~/lib/utils/datetime/date_calculation_utility';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import { Mousetrap } from '~/lib/mousetrap';
import { keysFor, SIDEBAR_CLOSE_WIDGET } from '~/behaviors/shortcuts/keybindings';
import { formatDate, pikadayToString } from '~/lib/utils/datetime_utility';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  sprintfWorkItem,
  TRACKING_CATEGORY_SHOW,
  WIDGET_TYPE_ROLLEDUP_DATES,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';

const nullObjectDate = new Date(0);

const ROLLUP_TYPE_FIXED = 'fixed';
const ROLLUP_TYPE_INHERITED = 'inherited';

export default {
  i18n: {
    dates: s__('WorkItem|Dates'),
    dueDate: s__('WorkItem|Due'),
    none: s__('WorkItem|None'),
    startDate: s__('WorkItem|Start'),
    fixed: s__('WorkItem|Fixed'),
    inherited: s__('WorkItem|Inherited'),
  },
  dueDateInputId: 'due-date-input',
  startDateInputId: 'start-date-input',
  components: {
    GlButton,
    GlDatepicker,
    GlFormGroup,
    GlFormRadio,
  },
  directives: {
    Outside,
  },
  mixins: [Tracking.mixin()],
  inject: ['isGroup'],
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    dueDateInherited: {
      type: String,
      required: false,
      default: null,
    },
    dueDateFixed: {
      type: String,
      required: false,
      default: null,
    },
    startDateInherited: {
      type: String,
      required: false,
      default: null,
    },
    startDateFixed: {
      type: String,
      required: false,
      default: null,
    },
    startDateIsFixed: {
      type: Boolean,
      required: false,
      default: false,
    },
    dueDateIsFixed: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemType: {
      type: String,
      required: true,
    },
    workItem: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      dirtyDueDate: null,
      dirtyStartDate: null,
      isUpdating: false,
      isEditing: false,
      rollupType: null,
    };
  },
  computed: {
    workItemId() {
      return this.workItem.id;
    },
    isFixed() {
      const dueDateIsFixedAndHasValue = this.dueDateIsFixed && this.dueDateFixed;
      const startDateIsFixedAndHasValue = this.startDateIsFixed && this.startDateFixed;

      return Boolean(
        (this.dueDateIsFixed && this.startDateIsFixed) ||
          dueDateIsFixedAndHasValue ||
          startDateIsFixedAndHasValue,
      );
    },
    dueDate() {
      return this.isFixed ? this.dueDateFixed : this.dueDateInherited;
    },
    startDate() {
      return this.isFixed ? this.startDateFixed : this.startDateInherited;
    },
    datesUnchanged() {
      const dirtyDueDate = this.dirtyDueDate || nullObjectDate;
      const dirtyStartDate = this.dirtyStartDate || nullObjectDate;
      const dueDate = this.dueDate ? newDateAsLocaleTime(this.dueDate) : nullObjectDate;
      const startDate = this.startDate ? newDateAsLocaleTime(this.startDate) : nullObjectDate;
      return (
        dirtyDueDate.getTime() === dueDate.getTime() &&
        dirtyStartDate.getTime() === startDate.getTime()
      );
    },
    isDatepickerDisabled() {
      return !this.canUpdate || this.isUpdating;
    },
    isWithOnlyDueDate() {
      return Boolean(this.dueDate && !this.startDate);
    },
    isWithOnlyStartDate() {
      return Boolean(!this.dueDate && this.startDate);
    },
    isWithNoDates() {
      return !this.dueDate && !this.startDate;
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_rolledup_dates',
        property: `type_${this.workItemType}`,
      };
    },
    startDateValue() {
      return this.startDate
        ? formatDate(this.startDate, 'mmm d, yyyy', true)
        : this.$options.i18n.none;
    },
    dueDateValue() {
      return this.dueDate ? formatDate(this.dueDate, 'mmm d, yyyy', true) : this.$options.i18n.none;
    },
    optimisticResponse() {
      const workItemDatesWidget = this.workItem.widgets.find(
        (widget) => widget.type === WIDGET_TYPE_ROLLEDUP_DATES,
      );

      return {
        workItemUpdate: {
          errors: [],
          workItem: {
            ...this.workItem,
            widgets: [
              ...this.workItem.widgets.filter(
                (widget) => widget.type !== WIDGET_TYPE_ROLLEDUP_DATES,
              ),
              {
                ...workItemDatesWidget,
                dueDate: this.dirtyDueDate ? pikadayToString(this.dirtyDueDate) : null,
                startDate: this.dirtyStartDate ? pikadayToString(this.dirtyStartDate) : null,
              },
            ],
          },
        },
      };
    },
  },
  watch: {
    dueDate: {
      handler(newDueDate) {
        this.dirtyDueDate = newDateAsLocaleTime(newDueDate);
      },
      immediate: true,
    },
    startDate: {
      handler(newStartDate) {
        this.dirtyStartDate = newDateAsLocaleTime(newStartDate);
      },
      immediate: true,
    },
  },
  mounted() {
    Mousetrap.bind(keysFor(SIDEBAR_CLOSE_WIDGET), this.collapseWidget);
    this.rollupType = this.isFixed ? ROLLUP_TYPE_FIXED : ROLLUP_TYPE_INHERITED;
  },
  beforeDestroy() {
    Mousetrap.unbind(keysFor(SIDEBAR_CLOSE_WIDGET));
  },
  methods: {
    clearDueDatePicker() {
      this.dirtyDueDate = null;
    },
    clearStartDatePicker() {
      this.dirtyStartDate = null;
    },
    handleStartDateInput() {
      if (this.dirtyDueDate && this.dirtyStartDate > this.dirtyDueDate) {
        this.dirtyDueDate = this.dirtyStartDate;
      }
    },
    updateRollupType() {
      this.isUpdating = true;

      this.track('updated_rollup_type');

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              isGroup: this.isGroup,
              workItemType: this.workItemType,
              fullPath: this.fullPath,
              rolledUpDates: {
                dueDateIsFixed: this.rollupType === ROLLUP_TYPE_FIXED,
                startDateIsFixed: this.rollupType === ROLLUP_TYPE_FIXED,
              },
            },
          },
        });

        this.isUpdating = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              rolledupDatesWidget: {
                dueDateIsFixed: this.rollupType === ROLLUP_TYPE_FIXED,
                startDateIsFixed: this.rollupType === ROLLUP_TYPE_FIXED,
              },
            },
          },
          optimisticResponse: this.optimisticResponse,
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('; '));
          }
        })
        .catch((error) => {
          const message = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', message);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
    updateDates() {
      if (this.datesUnchanged) {
        return;
      }

      this.track('updated_dates');

      this.isUpdating = true;
      this.rollupType = ROLLUP_TYPE_FIXED;

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              isGroup: this.isGroup,
              workItemType: this.workItemType,
              fullPath: this.fullPath,
              rolledUpDates: {
                dueDateIsFixed: true,
                startDateIsFixed: true,
                dueDateFixed: this.dirtyDueDate,
                startDateFixed: this.dirtyStartDate,
              },
            },
          },
        });

        this.isUpdating = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              rolledupDatesWidget: {
                dueDateIsFixed: true,
                startDateIsFixed: true,
                dueDateFixed: getDateWithUTC(this.dirtyDueDate),
                startDateFixed: getDateWithUTC(this.dirtyStartDate),
              },
            },
          },
          optimisticResponse: this.optimisticResponse,
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('; '));
          }
        })
        .catch((error) => {
          const message = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', message);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
    async expandWidget() {
      this.isEditing = true;
      await this.$nextTick();
      this.$refs.startDatePicker.show();
    },
    collapseWidget() {
      this.isEditing = false;
      this.updateDates();
    },
  },
};
</script>

<template>
  <section class="gl-pb-4" data-testid="work-item-rolledup-dates">
    <div class="gl-display-flex gl-align-items-center gl-gap-3">
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-mb-0! gl-heading-5">
        {{ $options.i18n.dates }}
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-button"
        category="tertiary"
        size="small"
        class="gl-ml-auto"
        :disabled="isUpdating"
        @click="expandWidget"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <fieldset v-if="!isEditing" class="gl-display-flex gl-gap-5 gl-mt-2">
      <gl-form-radio
        v-model="rollupType"
        value="fixed"
        :disabled="!canUpdate || isUpdating"
        @change="updateRollupType"
      >
        {{ $options.i18n.fixed }}
      </gl-form-radio>
      <gl-form-radio
        v-model="rollupType"
        value="inherited"
        :disabled="!canUpdate || isUpdating"
        @change="updateRollupType"
      >
        {{ $options.i18n.inherited }}
      </gl-form-radio>
    </fieldset>
    <fieldset v-if="isEditing" data-testid="datepicker-wrapper">
      <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
        <legend class="gl-mb-0 gl-border-b-0 gl-font-bold gl-font-base">
          {{ $options.i18n.dates }}
        </legend>
        <gl-button
          data-testid="apply-button"
          category="tertiary"
          size="small"
          class="gl-mr-2"
          :disabled="isUpdating"
          @click="collapseWidget"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <div v-outside="collapseWidget" class="gl-display-flex gl-pt-2">
        <gl-form-group
          class="gl-m-0"
          :label="$options.i18n.startDate"
          :label-for="$options.startDateInputId"
          label-class="!gl-font-normal gl-pb-2!"
        >
          <gl-datepicker
            ref="startDatePicker"
            v-model="dirtyStartDate"
            container="body"
            :disabled="isDatepickerDisabled"
            :input-id="$options.startDateInputId"
            show-clear-button
            :target="null"
            class="work-item-date-picker"
            @clear="clearStartDatePicker"
            @close="handleStartDateInput"
            @keydown.esc.native="collapseWidget"
          />
        </gl-form-group>
        <gl-form-group
          class="gl-m-0 gl-pl-3 gl-pr-2"
          :label="$options.i18n.dueDate"
          :label-for="$options.dueDateInputId"
          label-class="!gl-font-normal gl-pb-2!"
        >
          <gl-datepicker
            v-model="dirtyDueDate"
            container="body"
            :disabled="isDatepickerDisabled"
            :input-id="$options.dueDateInputId"
            :min-date="dirtyStartDate"
            show-clear-button
            :target="null"
            class="work-item-date-picker"
            data-testid="due-date-picker"
            @clear="clearDueDatePicker"
            @keydown.esc.native="collapseWidget"
          />
        </gl-form-group>
      </div>
    </fieldset>
    <template v-else>
      <p class="gl-m-0 gl-py-1">
        {{ $options.i18n.startDate }}:
        <span data-testid="start-date-value" :class="{ 'gl-text-secondary': !startDate }">
          {{ startDateValue }}
        </span>
      </p>
      <p class="gl-m-0 gl-pt-1 gl-pb-3">
        {{ $options.i18n.dueDate }}:
        <span data-testid="due-date-value" :class="{ 'gl-text-secondary': !dueDate }">
          {{ dueDateValue }}
        </span>
      </p>
    </template>
  </section>
</template>
