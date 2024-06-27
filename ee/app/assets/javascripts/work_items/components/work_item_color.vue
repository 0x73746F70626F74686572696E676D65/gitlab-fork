<script>
import {
  GlForm,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlButton,
  GlLoadingIcon,
} from '@gitlab/ui';
import { validateHexColor } from '~/lib/utils/color_utils';
import { __, s__ } from '~/locale';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  sprintfWorkItem,
  WIDGET_TYPE_COLOR,
  TRACKING_CATEGORY_SHOW,
  EPIC_COLORS,
  DEFAULT_EPIC_COLORS,
} from '~/work_items/constants';
import SidebarColorView from '~/sidebar/components/sidebar_color_view.vue';
import SidebarColorPicker from '~/sidebar/components/sidebar_color_picker.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import { newWorkItemId } from '~/work_items/utils';
import Tracking from '~/tracking';

export default {
  i18n: {
    colorLabel: __('Color'),
  },
  inputId: 'color-widget-input',
  suggestedColors: EPIC_COLORS,
  components: {
    GlForm,
    SidebarColorPicker,
    SidebarColorView,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlButton,
    GlLoadingIcon,
  },
  mixins: [Tracking.mixin()],
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
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
      currentColor: '',
      isEditing: false,
      isUpdating: false,
      errorMessage: '',
    };
  },
  computed: {
    workItemId() {
      return this.workItem?.id;
    },
    workItemType() {
      return this.workItem?.workItemType?.name;
    },
    workItemColorWidget() {
      return this.workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_COLOR);
    },
    color() {
      return this.workItemColorWidget?.color;
    },
    selectedColor() {
      // Check if current color hex code matches a suggested color key
      // If yes, return the named color from suggested color list
      // If no, return Custom
      if (this.suggestedColorKeys.includes(this.color?.toLowerCase())) {
        return Object.values(
          this.$options.suggestedColors.find(
            (item) => Object.keys(item)[0] === this.color?.toLowerCase(),
          ),
        ).pop();
      }
      return __('Custom');
    },
    textColor() {
      return this.workItemColorWidget?.textColor;
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_color',
        property: `type_${this.workItemType}`,
      };
    },
    suggestedColorKeys() {
      return this.$options.suggestedColors.map((item) => {
        return Object.keys(item).pop();
      });
    },
  },
  watch: {
    currentColor() {
      if (!validateHexColor(this.currentColor)) {
        this.errorMessage = s__('WorkItem|Must be a valid hex code');
      } else if (this.suggestedColorKeys.includes(this.currentColor)) {
        this.errorMessage = '';
        this.updateColor();
      } else {
        this.errorMessage = '';
      }
    },
  },
  created() {
    this.currentColor = this.color;
  },
  methods: {
    async updateColor() {
      if (
        !this.canUpdate ||
        this.color === this.currentColor ||
        !validateHexColor(this.currentColor)
      ) {
        this.isEditing = false;
        return;
      }

      this.isUpdating = true;

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              isGroup: this.isGroup,
              fullPath: this.fullPath,
              color: this.currentColor,
              workItemType: this.workItemType,
            },
          },
        });
        this.isUpdating = false;
        this.isEditing = false;
        return;
      }

      try {
        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              colorWidget: { color: this.currentColor },
            },
          },
          optimisticResponse: {
            workItemUpdate: {
              errors: [],
              workItem: {
                ...this.workItem,
                widgets: [
                  ...this.workItem.widgets,
                  {
                    color: this.currentColor,
                    textColor: this.textColor,
                    type: WIDGET_TYPE_COLOR,
                    __typename: 'WorkItemWidgetColor',
                  },
                ],
              },
            },
          },
        });

        if (errors.length) {
          throw new Error(errors.join('\n'));
        }
        this.track('updated_color');
      } catch {
        const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
        this.$emit('error', msg);
      } finally {
        this.isEditing = false;
        this.isUpdating = false;
      }
    },
    resetColor() {
      this.currentColor = DEFAULT_EPIC_COLORS;
      this.updateColor();
    },
  },
};
</script>
<template>
  <div class="work-item-color">
    <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-mb-0! gl-heading-5">
        {{ $options.i18n.colorLabel }}
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-color"
        category="tertiary"
        size="small"
        @click="isEditing = true"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <gl-form v-if="isEditing">
      <div class="gl-display-flex gl-align-items-center">
        <label :for="$options.inputId" class="gl-mb-0">{{ $options.i18n.colorLabel }}</label>
        <gl-loading-icon v-if="isUpdating" size="sm" inline class="gl-ml-3" />
        <gl-button
          data-testid="apply-color"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="updateColor"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <gl-disclosure-dropdown
        :id="$options.inputId"
        category="tertiary"
        :auto-close="false"
        start-opened
        @hidden="updateColor"
      >
        <template #header>
          <div
            class="gl-display-flex gl-align-items-center gl-py-2 gl-px-4 gl-min-h-8 gl-border-b-1 gl-border-b-solid gl-border-b-gray-200"
          >
            <span
              data-testid="color-header-title"
              class="gl-flex-grow-1 gl-font-bold gl-font-sm gl-pr-2 gl-leading-normal"
            >
              {{ __('Select a color') }}
            </span>
            <gl-button
              data-testid="reset-color"
              category="tertiary"
              size="small"
              class="gl-font-sm! gl-px-2! gl-py-2!"
              @click="resetColor"
              >{{ __('Reset') }}</gl-button
            >
          </div>
        </template>
        <template #toggle>
          <sidebar-color-view :color="color" :color-name="selectedColor" />
        </template>
        <gl-disclosure-dropdown-item>
          <sidebar-color-picker
            v-model="currentColor"
            :autofocus="true"
            :suggested-colors="$options.suggestedColors"
            :error-message="errorMessage"
            class="gl-px-2 gl-mt-2"
          />
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown>
    </gl-form>
    <div v-else class="work-item-field-value">
      <sidebar-color-view :color="color" :color-name="selectedColor" />
    </div>
  </div>
</template>
