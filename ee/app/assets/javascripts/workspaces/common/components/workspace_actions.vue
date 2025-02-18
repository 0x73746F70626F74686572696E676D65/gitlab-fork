<script>
import { GlButton, GlTooltip } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { s__ } from '~/locale';
import { WORKSPACE_DESIRED_STATES, WORKSPACE_STATES } from '../constants';

const RESTART_ACTION_VISIBLE_STATES = {
  [WORKSPACE_STATES.running]: [
    WORKSPACE_DESIRED_STATES.restartRequested,
    WORKSPACE_DESIRED_STATES.running,
  ],
  [WORKSPACE_STATES.stopped]: [
    WORKSPACE_DESIRED_STATES.restartRequested,
    WORKSPACE_DESIRED_STATES.stopped,
  ],
  [WORKSPACE_STATES.failed]: [
    WORKSPACE_DESIRED_STATES.restartRequested,
    WORKSPACE_DESIRED_STATES.running,
  ],
};

const START_ACTION_VISIBLE_STATES = {
  [WORKSPACE_STATES.creationRequested]: [
    WORKSPACE_DESIRED_STATES.running,
    WORKSPACE_DESIRED_STATES.stopped,
  ],
  [WORKSPACE_STATES.stopped]: [WORKSPACE_DESIRED_STATES.running, WORKSPACE_DESIRED_STATES.stopped],
  [WORKSPACE_STATES.starting]: [WORKSPACE_DESIRED_STATES.running, WORKSPACE_DESIRED_STATES.stopped],
};

const STOP_ACTION_VISIBLE_STATES = {
  [WORKSPACE_STATES.stopping]: [WORKSPACE_DESIRED_STATES.running, WORKSPACE_DESIRED_STATES.stopped],
  [WORKSPACE_STATES.running]: [WORKSPACE_DESIRED_STATES.running, WORKSPACE_DESIRED_STATES.stopped],
  [WORKSPACE_STATES.failed]: [WORKSPACE_DESIRED_STATES.running, WORKSPACE_DESIRED_STATES.stopped],
};

const stateIsInMap = (actualToDesired, actualState, desiredState) => {
  return actualToDesired[actualState]?.includes(desiredState);
};

const ACTIONS = [
  {
    key: 'restart',
    isVisible: (actualState, desiredState) =>
      stateIsInMap(RESTART_ACTION_VISIBLE_STATES, actualState, desiredState),
    desiredState: WORKSPACE_DESIRED_STATES.restartRequested,
    title: s__('Workspaces|Restart'),
    titleLoading: s__('Workspaces|Restarting'),
    icon: 'retry',
  },
  {
    key: 'start',
    isVisible: (actualState, desiredState) =>
      stateIsInMap(START_ACTION_VISIBLE_STATES, actualState, desiredState),
    desiredState: WORKSPACE_DESIRED_STATES.running,
    title: s__('Workspaces|Start'),
    titleLoading: s__('Workspaces|Starting'),
    icon: 'play',
  },
  {
    key: 'stop',
    isVisible: (actualState, desiredState) =>
      stateIsInMap(STOP_ACTION_VISIBLE_STATES, actualState, desiredState),
    desiredState: WORKSPACE_DESIRED_STATES.stopped,
    title: s__('Workspaces|Stop'),
    titleLoading: s__('Workspaces|Stopping'),
    icon: 'stop',
  },
  {
    key: 'terminate',
    isVisible: (actualState) =>
      ![WORKSPACE_STATES.unknown, WORKSPACE_STATES.terminated].includes(actualState),
    desiredState: WORKSPACE_DESIRED_STATES.terminated,
    title: s__('Workspaces|Terminate'),
    titleLoading: s__('Workspaces|Terminating'),
    icon: 'remove',
  },
];

export default {
  components: {
    GlButton,
    GlTooltip,
  },
  props: {
    actualState: {
      type: String,
      required: true,
    },
    desiredState: {
      type: String,
      required: true,
    },
    compact: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    actions() {
      return ACTIONS.filter(({ isVisible }) => isVisible(this.actualState, this.desiredState)).map(
        ({ desiredState, icon, key, titleLoading, title }) => {
          const isLoading = this.desiredState === desiredState;
          const tooltip = isLoading ? titleLoading : title;

          return {
            desiredState,
            icon,
            isLoading,
            key,
            id: uniqueId(`action-wrapper-${key}`),
            tooltip,
          };
        },
      );
    },
    compactButtonProps() {
      return this.compact ? { category: 'tertiary', size: 'small' } : {};
    },
  },
  methods: {
    onClick(actionDesiredState) {
      this.$emit('click', actionDesiredState);
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-justify-content-end">
    <span
      v-for="(action, idx) in actions"
      :id="action.id"
      :key="action.key"
      :class="idx > 0 ? 'gl-ml-2' : ''"
    >
      <gl-button
        :disabled="action.isLoading"
        :loading="action.isLoading"
        :aria-label="action.tooltip"
        :icon="action.icon"
        v-bind="compactButtonProps"
        :data-testid="`workspace-${action.key}-button`"
        @click.stop.prevent="onClick(action.desiredState)"
      />
      <gl-tooltip boundary="viewport" :target="action.id">
        {{ action.tooltip }}
      </gl-tooltip>
    </span>
  </div>
</template>
