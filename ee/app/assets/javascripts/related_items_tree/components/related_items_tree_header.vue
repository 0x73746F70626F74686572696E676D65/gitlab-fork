<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { TYPE_EPIC, TYPE_ISSUE } from '~/issues/constants';
import { __ } from '~/locale';
import { treeTitle, ParentType } from '../constants';
import EpicHealthStatus from './epic_health_status.vue';
import EpicActionsSplitButton from './epic_issue_actions_split_button.vue';

export default {
  components: {
    GlButton,
    EpicHealthStatus,
    EpicActionsSplitButton,
    EpicCountables: () =>
      import('ee_else_ce/vue_shared/components/epic_countables/epic_countables.vue'),
  },
  props: {
    isOpenString: {
      type: String,
      required: true,
      default: '',
    },
  },
  data() {
    return {
      isOpen: true,
    };
  },
  computed: {
    ...mapState([
      'parentItem',
      'weightSum',
      'descendantCounts',
      'healthStatus',
      'allowSubEpics',
      'allowIssuableHealthStatus',
    ]),
    showHealthStatus() {
      return this.healthStatus && this.allowIssuableHealthStatus;
    },
    parentIsEpic() {
      return this.parentItem.type === ParentType.Epic;
    },
    toggleIcon() {
      return this.isOpen ? 'chevron-lg-up' : 'chevron-lg-down';
    },
    toggleLabel() {
      return this.isOpen ? __('Collapse') : __('Expand');
    },
  },
  methods: {
    ...mapActions([
      'toggleCreateIssueForm',
      'toggleAddItemForm',
      'toggleCreateEpicForm',
      'setItemInputValue',
    ]),
    showAddIssueForm() {
      this.setItemInputValue('');
      this.toggleAddItemForm({
        issuableType: TYPE_ISSUE,
        toggleState: true,
      });
    },
    showCreateIssueForm() {
      this.toggleCreateIssueForm({
        toggleState: true,
      });
    },
    showAddEpicForm() {
      this.toggleAddItemForm({
        issuableType: TYPE_EPIC,
        toggleState: true,
      });
    },
    showCreateEpicForm() {
      this.toggleCreateEpicForm({
        toggleState: true,
      });
    },
    handleToggle() {
      this.isOpen = !this.isOpen;
      this.$emit('toggleRelatedItemsView', this.isOpen);
    },
  },
  treeTitle,
};
</script>

<template>
  <div class="gl-new-card-header">
    <div class="gl-new-card-title-wrapper">
      <div class="gl-display-flex gl-flex-shrink-0 gl-align-items-center gl-flex-wrap">
        <h3 class="gl-new-card-title">
          {{ allowSubEpics ? __('Child issues and epics') : $options.treeTitle[parentItem.type] }}
        </h3>
        <div
          v-if="parentIsEpic"
          class="gl-inline-flex gl-leading-1 gl-align-middle gl-ml-3 gl-flex-wrap"
        >
          <epic-countables
            :allow-sub-epics="allowSubEpics"
            :opened-epics-count="descendantCounts.openedEpics"
            :closed-epics-count="descendantCounts.closedEpics"
            :opened-issues-count="descendantCounts.openedIssues"
            :closed-issues-count="descendantCounts.closedIssues"
            :opened-issues-weight="weightSum.openedIssues"
            :closed-issues-weight="weightSum.closedIssues"
          />
        </div>
      </div>
      <div
        class="gl-flex sm:gl-inline-flex gl-leading-1 gl-align-middle gl-sm-ml-2 gl-ml-0 gl-flex-wrap gl-mt-2 gl-sm-mt-0"
      >
        <epic-health-status v-if="showHealthStatus" :health-status="healthStatus" />
      </div>
    </div>

    <div
      v-if="parentIsEpic"
      class="gl-flex sm:gl-inline-flex gl-sm-ml-auto gl-leading-1 gl-align-middle gl-mt-3 gl-sm-mt-0 gl-pl-0 gl-sm-pl-7"
    >
      <div
        class="gl-flex-grow-1 gl-flex-direction-column gl-sm-flex-direction-row js-button-container"
      >
        <epic-actions-split-button
          :allow-sub-epics="allowSubEpics"
          class="js-add-epics-issues-button gl-w-full"
          @showAddIssueForm="showAddIssueForm"
          @showCreateIssueForm="showCreateIssueForm"
          @showAddEpicForm="showAddEpicForm"
          @showCreateEpicForm="showCreateEpicForm"
        />
      </div>
      <div class="gl-new-card-toggle">
        <gl-button
          category="tertiary"
          size="small"
          :icon="toggleIcon"
          :aria-expanded="isOpenString"
          :aria-label="toggleLabel"
          data-testid="toggle-links"
          @click="handleToggle"
        />
      </div>
    </div>
  </div>
</template>
