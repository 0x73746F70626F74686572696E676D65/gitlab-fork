<script>
import { GlDisclosureDropdownItem } from '@gitlab/ui';
import Tracking from '~/tracking';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import WorkspaceStateIndicator from '../../common/components/workspace_state_indicator.vue';
import WorkspaceActions from '../../common/components/workspace_actions.vue';

export default {
  components: {
    GlDisclosureDropdownItem,
    WorkspaceStateIndicator,
    WorkspaceActions,
    TimeAgoTooltip,
  },
  mixins: [Tracking.mixin()],
  props: {
    workspace: {
      type: Object,
      required: true,
    },
  },
  computed: {
    dropdownItem() {
      return {
        href: this.workspace.url,
        text: this.workspace.name,
      };
    },
  },
  methods: {
    trackOpenWorkspace() {
      this.track('click_consolidated_edit', { label: 'workspace' });
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown-item class="gl-my-0" :item="dropdownItem" @action="trackOpenWorkspace">
    <template #list-item>
      <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
        <span class="gl-inline-flex gl-flex-direction-column gl-align-items-flex-start">
          <workspace-state-indicator class="gl-mb-2" :workspace-state="workspace.actualState" />
          <span class="gl-pl-1 gl-break-anywhere gl-w-9/10">{{ workspace.name }}</span>
          <time-ago-tooltip
            class="gl-font-sm-600 gl-pl-1 gl-text-secondary gl-mt-2"
            :time="workspace.createdAt"
          />
        </span>
        <workspace-actions
          :actual-state="workspace.actualState"
          :desired-state="workspace.desiredState"
          compact
          @click="$emit('updateWorkspace', { desiredState: $event })"
        />
      </div>
    </template>
  </gl-disclosure-dropdown-item>
</template>
