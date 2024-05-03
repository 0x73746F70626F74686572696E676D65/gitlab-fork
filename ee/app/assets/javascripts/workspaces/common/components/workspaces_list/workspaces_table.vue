<script>
import { GlTableLite, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { WORKSPACE_STATES } from '../../constants';
import WorkspaceStateIndicator from '../workspace_state_indicator.vue';
import UpdateWorkspaceMutation from '../update_workspace_mutation.vue';
import WorkspaceActions from '../workspace_actions.vue';

const isTerminated = (w) => w.actualState === WORKSPACE_STATES.terminated;

// Moves terminated workspaces to the end of the list
const sortWorkspacesByTerminatedState = (workspaceA, workspaceB) => {
  const isWorkspaceATerminated = isTerminated(workspaceA);
  const isWorkspaceBTerminated = isTerminated(workspaceB);

  if (isWorkspaceATerminated === isWorkspaceBTerminated) {
    return 0; // Preserve default order when neither workspace is terminated, or both workspaces are terminated.
  }
  if (isWorkspaceATerminated) {
    return 1; // Place workspaceA after workspaceB since it is terminated.
  }

  return -1; // Place workspaceA before workspaceB since it is not terminated.
};

export const i18n = {
  tableColumnHeaders: {
    name: __('Name'),
    devfile: __('Devfile'),
    preview: __('Preview'),
    created: __('Created'),
  },
};

export default {
  components: {
    GlTableLite,
    GlLink,
    WorkspaceStateIndicator,
    WorkspaceActions,
    UpdateWorkspaceMutation,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workspaces: {
      type: Array,
      required: true,
    },
  },
  computed: {
    sortedWorkspaces() {
      return [...this.workspaces].sort(sortWorkspacesByTerminatedState);
    },
  },
  methods: {
    devfileRefAndPathDisplay(ref, path) {
      if (!ref || !path) {
        return '';
      }
      return sprintf(__(`%{path} on %{ref}`), { ref, path });
    },
  },
  fields: [
    {
      key: 'status',
      /*
       * The status and action columns in this table
       * do not have a label in the table header. We
       * use this zero-width unicode character because
       * using an empty string breaks the table alignment
       * in mobile views.
       */
      label: '\u200b',
      thClass: 'gl-w-1/20',
    },
    {
      key: 'name',
      label: i18n.tableColumnHeaders.name,
      thClass: 'gl-w-4/20',
    },
    {
      key: 'created',
      label: i18n.tableColumnHeaders.created,
      thClass: 'gl-w-3/20',
    },
    {
      key: 'devfile',
      label: i18n.tableColumnHeaders.devfile,
      thClass: 'gl-w-4/20',
    },
    {
      key: 'preview',
      label: i18n.tableColumnHeaders.preview,
      thClass: 'gl-w-4/20',
    },
    {
      key: 'actions',
      label: '\u200b',
      thClass: 'gl-w-4/20',
    },
  ],
  i18n,
  WORKSPACE_STATES,
};
</script>
<template>
  <update-workspace-mutation
    @updateFailed="$emit('updateFailed', $event)"
    @updateSucceed="$emit('updateSucceed')"
  >
    <template #default="{ update }">
      <gl-table-lite
        :items="sortedWorkspaces"
        stacked="sm"
        :fields="$options.fields"
        :tbody-tr-attr="(item) => ({ 'data-testid': item.name })"
      >
        <template #cell(status)="{ item }">
          <workspace-state-indicator class="gl-mr-5" :workspace-state="item.actualState" />
        </template>
        <template #cell(name)="{ item }">
          <div class="gl-display-flex gl-flex-direction-column">
            <span class="gl-text-gray-500 gl-font-sm gl-pb-1"> {{ item.projectName }} </span>
            <span class="gl-text-black-normal"> {{ item.name }} </span>
          </div>
        </template>
        <template #cell(created)="{ item }">
          <time-ago-tooltip
            class="gl-white-space-nowrap gl-font-sm-600 gl-text-secondary"
            :time="item.createdAt"
          />
        </template>
        <template #cell(devfile)="{ item }">
          <gl-link
            v-gl-tooltip
            :title="item.devfileWebUrl"
            :href="item.devfileWebUrl"
            class="workspace-list-link"
            target="_blank"
            :data-testid="`${item.name}-link`"
          >
            {{ devfileRefAndPathDisplay(item.devfileRef, item.devfilePath) }}
          </gl-link>
        </template>
        <template #cell(preview)="{ item }">
          <gl-link
            v-if="item.actualState === $options.WORKSPACE_STATES.running"
            :href="item.url"
            class="workspace-list-link"
            target="_blank"
            :data-testid="`${item.name}-link`"
            >{{ item.url }}
          </gl-link>
        </template>
        <template #cell(actions)="{ item }">
          <workspace-actions
            :actual-state="item.actualState"
            :desired-state="item.desiredState"
            :data-testid="`${item.name}-action`"
            @click="update(item.id, { desiredState: $event })"
          />
        </template>
      </gl-table-lite>
    </template>
  </update-workspace-mutation>
</template>
