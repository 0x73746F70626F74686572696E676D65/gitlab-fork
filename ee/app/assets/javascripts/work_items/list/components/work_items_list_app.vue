<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState } from '@gitlab/ui';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC } from '~/work_items/constants';
import WorkItemsListApp from '~/work_items/list/components/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_ENUM_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    WorkItemsListApp,
  },
  inject: ['hasEpicsFeature', 'showNewIssueLink'],
  data() {
    return {
      createdWorkItemsCount: 0,
    };
  },
  methods: {
    handleCreated() {
      this.createdWorkItemsCount += 1;
    },
  },
};
</script>

<template>
  <work-items-list-app :ee-created-work-items-count="createdWorkItemsCount">
    <template v-if="hasEpicsFeature && showNewIssueLink" #nav-actions>
      <create-work-item-modal
        class="gl-flex-grow-1"
        :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
        @workItemCreated="handleCreated"
      />
    </template>
    <template v-if="hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues :has-search="hasSearch" is-epic :is-open-tab="isOpenTab">
        <template v-if="showNewIssueLink" #new-issue-button>
          <create-work-item-modal
            class="gl-flex-grow-1"
            :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
            @workItemCreated="handleCreated"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="hasEpicsFeature" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewIssueLink" #actions>
          <create-work-item-modal
            class="gl-flex-grow-1"
            :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
            @workItemCreated="handleCreated"
          />
        </template>
      </gl-empty-state>
    </template>
  </work-items-list-app>
</template>
