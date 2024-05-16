<script>
import { GlToggle } from '@gitlab/ui';
import { __ } from '~/locale';
import Tracking from '~/tracking';
import { historyPushState } from '~/lib/utils/common_utils';
import { mergeUrlParams, removeParams } from '~/lib/utils/url_utility';
import { GroupByParamType } from 'ee_else_ce/boards/constants';

const trackingMixin = Tracking.mixin();

const EPIC_KEY = 'epic';
const NO_GROUPING_KEY = 'no_grouping';

const LIST_BOX_ITEMS = [
  {
    value: NO_GROUPING_KEY,
    text: __('No grouping'),
  },
  {
    value: EPIC_KEY,
    text: __('Epic'),
  },
];

export default {
  LIST_BOX_ITEMS,
  components: {
    GlToggle,
  },
  mixins: [trackingMixin],
  props: {
    isSwimlanesOn: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    dropdownLabel() {
      return this.isSwimlanesOn ? LIST_BOX_ITEMS[1].text : __('None');
    },
    selected() {
      return this.isSwimlanesOn ? EPIC_KEY : NO_GROUPING_KEY;
    },
  },
  methods: {
    toggleEpicSwimlanes() {
      if (this.isSwimlanesOn) {
        historyPushState(removeParams(['group_by']), window.location.href, true);
        this.$emit('toggleSwimlanes', false);
      } else {
        historyPushState(
          mergeUrlParams({ group_by: GroupByParamType.epic }, window.location.href, {
            spreadArrays: true,
          }),
        );
        this.$emit('toggleSwimlanes', true);
      }
    },
    onToggle() {
      // Track toggle event
      this.track('click_toggle_swimlanes_button', {
        label: 'toggle_swimlanes',
        property: this.isSwimlanesOn ? 'off' : 'on',
      });

      // Track if the board has swimlane active
      if (!this.isSwimlanesOn) {
        this.track('click_toggle_swimlanes_button', {
          label: 'swimlanes_active',
        });
      }

      this.toggleEpicSwimlanes();
    },
  },
};
</script>

<template>
  <gl-toggle
    :value="isSwimlanesOn"
    :label="__('Epic swimlanes')"
    label-position="left"
    data-testid="epic-swimlanes-toggle"
    class="gl-flex-direction-row gl-justify-between gl-w-full"
    @change="onToggle"
  />
</template>
