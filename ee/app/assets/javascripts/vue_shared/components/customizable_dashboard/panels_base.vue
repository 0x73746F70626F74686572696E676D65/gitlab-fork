<script>
import { GlDisclosureDropdown, GlIcon, GlLoadingIcon, GlPopover } from '@gitlab/ui';
import { alertVariantIconMap } from '@gitlab/ui/src/utils/constants';
import uniqueId from 'lodash/uniqueId';
import { isObject } from 'lodash';
import { VARIANT_DANGER, VARIANT_WARNING, VARIANT_INFO } from '~/alert';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import { PANEL_POPOVER_DELAY } from './constants';

export default {
  name: 'PanelsBase',
  components: {
    GlDisclosureDropdown,
    GlLoadingIcon,
    GlIcon,
    GlPopover,
    TooltipOnTruncate,
  },
  props: {
    title: {
      type: String,
      required: false,
      default: '',
    },
    tooltip: {
      type: String,
      required: false,
      default: '',
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    loadingDelayed: {
      type: Boolean,
      required: false,
      default: false,
    },
    showAlertState: {
      type: Boolean,
      required: false,
      default: false,
    },
    alertVariant: {
      type: String,
      required: false,
      default: VARIANT_DANGER,
      validator: (variant) => [VARIANT_WARNING, VARIANT_DANGER, VARIANT_INFO].includes(variant),
    },
    alertPopoverTitle: {
      type: String,
      required: false,
      default: '',
    },
    actions: {
      type: Array,
      required: false,
      default: () => [],
      validator: (actions) => actions.every((a) => isObject(a)),
    },
    editing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      popoverId: uniqueId('panel-alert-popover-'),
      dropdownOpen: false,
    };
  },
  computed: {
    alertClasses() {
      const borderColor = this.showAlertState
        ? this.$options.alertBorderColorMap[this.alertVariant]
        : '';

      return `gl-border-t-2 gl-border-t-solid ${borderColor}`;
    },
    alertIconClasses() {
      return this.$options.alertIconClassMap[this.alertVariant];
    },
    alertIcon() {
      return this.$options.alertVariantIconMap[this.alertVariant] ?? alertVariantIconMap.danger;
    },
    showAlertPopover() {
      return this.showAlertState && !this.dropdownOpen;
    },
  },
  PANEL_POPOVER_DELAY,
  alertVariantIconMap,
  alertBorderColorMap: {
    [VARIANT_DANGER]: 'gl-border-t-red-500',
    [VARIANT_WARNING]: 'gl-border-t-orange-500',
    [VARIANT_INFO]: 'gl-border-t-blue-500',
  },
  alertIconClassMap: {
    [VARIANT_DANGER]: 'gl-text-red-500',
    [VARIANT_WARNING]: 'gl-text-orange-500',
    [VARIANT_INFO]: 'gl-text-blue-500',
  },
};
</script>

<template>
  <div
    :id="popoverId"
    class="grid-stack-item-content gl-border gl-rounded-base gl-p-4 gl-bg-white gl-overflow-visible! gl-h-full"
    :class="alertClasses"
  >
    <div class="gl-h-full gl-display-flex gl-flex-direction-column">
      <div
        class="gl-display-flex gl-align-items-flex-start gl-justify-content-space-between"
        data-testid="panel-title"
      >
        <tooltip-on-truncate
          v-if="title"
          :title="title"
          placement="top"
          boundary="viewport"
          class="gl-pb-3 gl-text-truncate"
        >
          <gl-icon
            v-if="showAlertState"
            class="gl-mr-1"
            :class="alertIconClasses"
            :name="alertIcon"
            data-testid="panel-title-alert-icon"
          />
          <strong class="gl-text-gray-700">{{ title }}</strong>
          <template v-if="tooltip">
            <gl-icon
              ref="titleTooltip"
              data-testid="panel-title-tooltip-icon"
              name="information-o"
            />
            <gl-popover
              data-testid="panel-title-popover"
              boundary="viewport"
              :target="() => $refs.titleTooltip.$el"
            >
              {{ tooltip }}
            </gl-popover>
          </template>
        </tooltip-on-truncate>

        <gl-disclosure-dropdown
          v-if="editing"
          :items="actions"
          icon="ellipsis_v"
          :toggle-text="__('Actions')"
          text-sr-only
          no-caret
          placement="right"
          fluid-width
          toggle-class="gl-ml-1"
          category="tertiary"
          positioning-strategy="fixed"
          @shown="dropdownOpen = true"
          @hidden="dropdownOpen = false"
        >
          <template #list-item="{ item }">
            <span> <gl-icon :name="item.icon" /> {{ item.text }}</span>
          </template>
        </gl-disclosure-dropdown>
      </div>
      <div
        class="gl-overflow-x-hidden gl-overflow-y-auto gl-flex-grow-1"
        :class="{ 'gl-flex gl-flex-wrap gl-text-center gl-content-center': loading }"
      >
        <template v-if="loading">
          <gl-loading-icon size="lg" class="gl-w-full" />
          <div
            v-if="loadingDelayed"
            class="gl-w-full gl-text-secondary"
            data-testId="panel-loading-delayed-indicator"
          >
            {{ __('Still loading...') }}
          </div>
        </template>
        <!-- @slot The panel body to display when not loading. -->
        <slot v-else name="body"></slot>
      </div>

      <gl-popover
        v-if="showAlertPopover"
        triggers="hover focus"
        :title="alertPopoverTitle"
        :show-close-button="false"
        placement="top"
        :css-classes="['gl-max-w-1/2']"
        :target="popoverId"
        :delay="$options.PANEL_POPOVER_DELAY"
        boundary="viewport"
      >
        <!-- @slot The panel error popover body to display when showAlertState is true. -->
        <slot name="alert-popover"></slot>
      </gl-popover>
    </div>
  </div>
</template>
