<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __, n__ } from '~/locale';
import { EPIC_DETAILS_CELL_WIDTH, EPIC_ITEM_HEIGHT, TIMELINE_CELL_MIN_WIDTH } from '../constants';
import eventHub from '../event_hub';
import { scrollToCurrentDay } from '../utils/epic_utils';
import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';

import MilestoneTimeline from './milestone_timeline.vue';

const EXPAND_BUTTON_EXPANDED = {
  name: 'chevron-down',
  iconLabel: __('Collapse milestones'),
  tooltip: __('Collapse'),
};

const EXPAND_BUTTON_COLLAPSED = {
  name: 'chevron-right',
  iconLabel: __('Expand milestones'),
  tooltip: __('Expand'),
};

export default {
  components: {
    MilestoneTimeline,
    GlButton,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    milestones: {
      type: Array,
      required: true,
    },
    timeframe: {
      type: Array,
      required: true,
    },
    bufferSize: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      offsetLeft: 0,
      showBottomShadow: false,
      roadmapShellEl: null,
      milestonesExpanded: true,
    };
  },
  computed: {
    sectionContainerStyles() {
      return {
        width: `${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * this.timeframe.length}px`,
      };
    },
    shadowCellStyles() {
      return {
        left: `${this.offsetLeft}px`,
      };
    },
    expandButton() {
      return this.milestonesExpanded ? EXPAND_BUTTON_EXPANDED : EXPAND_BUTTON_COLLAPSED;
    },
    milestonesCount() {
      return this.milestones.length;
    },
    milestonesCountText() {
      return Number.isInteger(this.milestonesCount)
        ? n__(`%d milestone`, `%d milestones`, this.milestonesCount)
        : '';
    },
  },
  mounted() {
    eventHub.$on('epicsListScrolled', this.handleEpicsListScroll);
    this.initMounted();
    this.$emit('milestonesMounted');
  },
  beforeDestroy() {
    eventHub.$off('epicsListScrolled', this.handleEpicsListScroll);
  },
  methods: {
    initMounted() {
      this.roadmapShellEl = this.$root.$el && this.$root.$el.firstChild;
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: {
            bufferSize: Math.ceil((window.innerHeight - this.$el.offsetTop) / EPIC_ITEM_HEIGHT),
          },
        },
      });

      this.$nextTick(() => {
        this.offsetLeft = (this.$el.parentElement && this.$el.parentElement.offsetLeft) || 0;

        this.$nextTick(() => {
          scrollToCurrentDay(this.$el);
        });
      });
    },
    handleEpicsListScroll({ scrollTop, clientHeight, scrollHeight }) {
      this.showBottomShadow = Math.ceil(scrollTop) + clientHeight < scrollHeight;
    },
    toggleMilestonesExpanded() {
      this.milestonesExpanded = !this.milestonesExpanded;
    },
  },
};
</script>

<template>
  <div
    :style="sectionContainerStyles"
    class="milestones-list-section gl-table clearfix"
    data-testid="milestones-list-wrapper"
  >
    <div
      class="milestones-list-title gl-table-cell border-bottom gl-align-top position-sticky gl-pl-5 xl:gl-pl-6 gl-pr-3 gl-pt-2"
    >
      <div class="gl-display-flex gl-align-items-center">
        <span
          v-gl-tooltip.hover.topright="{
            title: expandButton.tooltip,
            offset: 15,
            boundary: 'viewport',
          }"
          data-testid="expandButton"
        >
          <gl-button
            :aria-label="expandButton.iconLabel"
            category="tertiary"
            size="small"
            :icon="expandButton.name"
            @click="toggleMilestonesExpanded"
          />
        </span>
        <div class="gl-overflow-hidden gl-flex-grow-1 gl-ml-2 gl-mr-3 gl-font-bold">
          {{ __('Milestones') }}
        </div>
        <div
          v-gl-tooltip="milestonesCountText"
          class="gl-display-flex gl-align-items-center gl-justify-content-center text-secondary gl-whitespace-nowrap"
          data-testid="count"
        >
          <gl-icon name="milestone" class="gl-mr-2" />
          <span :aria-label="milestonesCountText">{{ milestonesCount }}</span>
        </div>
      </div>
    </div>
    <div class="milestones-list-items gl-table-cell">
      <milestone-timeline
        :timeframe="timeframe"
        :milestones="milestones"
        :milestones-expanded="milestonesExpanded"
      />
    </div>
    <div
      v-show="showBottomShadow"
      :style="shadowCellStyles"
      class="scroll-bottom-shadow"
      data-testid="scroll-bottom-shadow"
    ></div>
  </div>
</template>
