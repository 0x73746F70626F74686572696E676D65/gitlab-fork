<script>
import { GlDrawer } from '@gitlab/ui';

import updateLocalRoadmapSettingsMutation from '../queries/update_local_roadmap_settings.mutation.graphql';
import localRoadmapSettingsQuery from '../queries/local_roadmap_settings.query.graphql';

import { mapLocalSettings } from '../utils/roadmap_utils';

import RoadmapDaterange from './roadmap_daterange.vue';
import RoadmapEpicsState from './roadmap_epics_state.vue';
import RoadmapMilestones from './roadmap_milestones.vue';
import RoadmapProgressTracking from './roadmap_progress_tracking.vue';
import RoadmapToggleLabels from './roadmap_toggle_labels.vue';

export default {
  components: {
    GlDrawer,
    RoadmapDaterange,
    RoadmapMilestones,
    RoadmapEpicsState,
    RoadmapProgressTracking,
    RoadmapToggleLabels,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      headerHeight: '0px',
    };
  },
  apollo: {
    localRoadmapSettings: {
      query: localRoadmapSettingsQuery,
    },
  },
  computed: {
    ...mapLocalSettings([
      'epicsState',
      'progressTracking',
      'isProgressTrackingActive',
      'milestonesType',
      'isShowingMilestones',
      'isShowingLabels',
    ]),
  },
  watch: {
    isOpen(newIsOpen) {
      if (newIsOpen === true) {
        this.setHeaderHeight();
      }
    },
  },
  methods: {
    setLocalSettings(settings) {
      this.$apollo.mutate({
        mutation: updateLocalRoadmapSettingsMutation,
        variables: {
          input: settings,
        },
      });
    },
    setHeaderHeight() {
      const { offsetTop = 0 } = this.$root.$el;
      const clientHeight = this.$parent.$refs?.roadmapFilters?.$el.clientHeight || 0;

      this.headerHeight = `${offsetTop + clientHeight}px`;
    },
  },
};
</script>

<template>
  <gl-drawer
    v-bind="$attrs"
    :open="isOpen"
    :z-index="20"
    :header-height="headerHeight"
    @close="$emit('toggleSettings', $event)"
  >
    <template #title>
      <h2 class="gl-my-0 gl-font-size-h2 gl-line-height-24">{{ __('Roadmap settings') }}</h2>
    </template>
    <template #default>
      <roadmap-daterange @setDateRange="setLocalSettings" />
      <roadmap-milestones
        :milestones-type="milestonesType"
        :is-showing-milestones="isShowingMilestones"
        @setMilestonesSettings="setLocalSettings"
      />
      <roadmap-epics-state :epics-state="epicsState" @setEpicsState="setLocalSettings" />
      <roadmap-progress-tracking
        :progress-tracking="progressTracking"
        :is-progress-tracking-active="isProgressTrackingActive"
        @setProgressTracking="setLocalSettings"
      />
      <roadmap-toggle-labels
        :is-showing-labels="isShowingLabels"
        @setLabelsVisibility="setLocalSettings"
      />
    </template>
  </gl-drawer>
</template>
