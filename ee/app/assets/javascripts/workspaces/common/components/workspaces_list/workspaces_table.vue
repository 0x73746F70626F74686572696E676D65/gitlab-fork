<script>
import { GlTableLite, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { getTimeago, nSecondsAfter } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { WORKSPACE_STATES } from '../../constants';
import WorkspaceStateIndicator from '../workspace_state_indicator.vue';
import UpdateWorkspaceMutation from '../update_workspace_mutation.vue';
import WorkspaceActions from '../workspace_actions.vue';

export const i18n = {
  tableColumnHeaders: {
    name: __('Name'),
    devfile: __('Devfile'),
    preview: __('Preview'),
    created: __('Created'),
    terminates: __('Terminates'),
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
  data() {
    return {
      transitionProps: {
        name: 'fade',
        delay: 200,
        duration: 300,
      },
    };
  },
  computed: {
    sortedWorkspaces() {
      return [...this.workspaces].sort(this.sortWorkspacesByTerminatedState);
    },
  },
  methods: {
    devfileRefAndPathDisplay(ref, path) {
      if (!ref || !path) {
        return '';
      }
      return sprintf(__(`%{path} on %{ref}`), { ref, path });
    },
    terminatesIn(workspace) {
      const createdAt = new Date(workspace.createdAt);
      const terminationDate = nSecondsAfter(
        createdAt,
        workspace.maxHoursBeforeTermination * 60 * 60,
      );

      return getTimeago().format(terminationDate, { relativeDate: createdAt });
    },
    // Moves terminated workspaces to the end of the list
    sortWorkspacesByTerminatedState(workspaceA, workspaceB) {
      const isWorkspaceATerminated = this.isTerminated(workspaceA);
      const isWorkspaceBTerminated = this.isTerminated(workspaceB);

      if (isWorkspaceATerminated === isWorkspaceBTerminated) {
        return 0; // Preserve default order when neither workspace is terminated, or both workspaces are terminated.
      }
      if (isWorkspaceATerminated) {
        return 1; // Place workspaceA after workspaceB since it is terminated.
      }

      return -1; // Place workspaceA before workspaceB since it is not terminated.
    },
    isTerminated(workspace) {
      return workspace.actualState === WORKSPACE_STATES.terminated;
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
      thClass: 'gl-w-2/20',
    },
    {
      key: 'terminates',
      label: i18n.tableColumnHeaders.terminates,
      thClass: 'gl-w-2/20',
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
        :tbody-transition-props="transitionProps"
        primary-key="name"
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
            class="gl-whitespace-nowrap gl-font-sm-600 gl-text-secondary"
            :time="item.createdAt"
          />
        </template>
        <template #cell(terminates)="{ item }">
          <div
            v-if="!isTerminated(item)"
            class="gl-whitespace-nowrap gl-font-sm-600 gl-text-secondary"
            :data-testid="`${item.name}-terminates`"
          >
            {{ terminatesIn(item) }}
          </div>
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
