<script>
import { GlButton, GlDisclosureDropdown, GlLabel } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { difference } from 'lodash';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import { __, n__ } from '~/locale';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import DropdownContentsCreateView from '~/sidebar/components/labels/labels_select_widget/dropdown_contents_create_view.vue';
import groupLabelsQuery from '~/sidebar/components/labels/labels_select_widget/graphql/group_labels.query.graphql';
import projectLabelsQuery from '~/sidebar/components/labels/labels_select_widget/graphql/project_labels.query.graphql';
import { isScopedLabel } from '~/lib/utils/common_utils';
import Tracking from '~/tracking';
import groupWorkItemByIidQuery from '../graphql/group_work_item_by_iid.query.graphql';
import workItemByIidQuery from '../graphql/work_item_by_iid.query.graphql';
import updateWorkItemMutation from '../graphql/update_work_item.mutation.graphql';
import updateNewWorkItemMutation from '../graphql/update_new_work_item.mutation.graphql';
import { i18n, I18N_WORK_ITEM_ERROR_FETCHING_LABELS, TRACKING_CATEGORY_SHOW } from '../constants';
import { isLabelsWidget, newWorkItemId, newWorkItemFullPath } from '../utils';

export default {
  components: {
    DropdownContentsCreateView,
    GlButton,
    GlDisclosureDropdown,
    GlLabel,
    WorkItemSidebarDropdownWidget,
  },
  mixins: [Tracking.mixin()],
  inject: ['canAdminLabel', 'isGroup', 'issuesListPath', 'labelsManagePath'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    createFlow: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      searchTerm: '',
      searchStarted: false,
      showLabelForm: false,
      updateInProgress: false,
      createdLabelId: undefined,
      removeLabelIds: [],
      addLabelIds: [],
    };
  },
  computed: {
    workItemFullPath() {
      return this.createFlow
        ? newWorkItemFullPath(this.fullPath, this.workItemType)
        : this.fullPath;
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_label',
        property: `type_${this.workItemType}`,
      };
    },
    areLabelsSelected() {
      return this.addLabelIds.length > 0 || this.itemValues.length > 0;
    },
    selectedLabelCount() {
      return this.addLabelIds.length + this.itemValues.length - this.removeLabelIds.length;
    },
    dropDownLabelText() {
      return n__('%d label', '%d labels', this.selectedLabelCount);
    },
    dropdownText() {
      return this.areLabelsSelected ? `${this.dropDownLabelText}` : __('No labels');
    },
    isLoadingLabels() {
      return this.$apollo.queries.searchLabels.loading;
    },
    visibleLabels() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.searchLabels, this.searchTerm, {
          key: ['title'],
        });
      }
      return this.searchLabels;
    },
    labelsList() {
      return this.visibleLabels?.map(({ id, title, color }) => ({
        value: id,
        text: title,
        color,
      }));
    },
    labelsWidget() {
      return this.workItem?.widgets?.find(isLabelsWidget);
    },
    localLabels() {
      return this.labelsWidget?.labels?.nodes || [];
    },
    itemValues() {
      return this.localLabels.map(({ id }) => id);
    },
    allowsScopedLabels() {
      return this.labelsWidget?.allowsScopedLabels;
    },
    createLabelText() {
      return this.isGroup ? __('Create group label') : __('Create project label');
    },
    manageLabelText() {
      return this.isGroup ? __('Manage group labels') : __('Manage project labels');
    },
    workspaceType() {
      return this.isGroup ? WORKSPACE_GROUP : WORKSPACE_PROJECT;
    },
  },
  apollo: {
    workItem: {
      query() {
        return this.isGroup ? groupWorkItemByIidQuery : workItemByIidQuery;
      },
      variables() {
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
        };
      },
      update(data) {
        return data.workspace?.workItem || {};
      },
      skip() {
        return !this.workItemIid;
      },
      error() {
        this.$emit('error', i18n.fetchError);
      },
    },
    searchLabels: {
      query() {
        return this.isGroup ? groupLabelsQuery : projectLabelsQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          searchTerm: this.searchTerm,
        };
      },
      skip() {
        return !this.searchStarted;
      },
      update(data) {
        return data.workspace?.labels?.nodes;
      },
      error() {
        this.$emit('error', I18N_WORK_ITEM_ERROR_FETCHING_LABELS);
      },
    },
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.searchStarted = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.searchStarted = true;
    },
    removeLabel({ id }) {
      this.removeLabelIds.push(id);
      this.updateLabels();
    },
    updateLabel(labels) {
      this.removeLabelIds = difference(this.itemValues, labels);
      this.addLabelIds = difference(labels, this.itemValues);
    },
    async updateLabels(labels) {
      this.updateInProgress = true;

      if (labels?.length === 0) {
        this.removeLabelIds = this.itemValues;
        this.addLabelIds = [];
      }

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        const selectedIds = [...this.itemValues, ...this.addLabelIds].filter(
          (x) => !this.removeLabelIds.includes(x),
        );

        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              isGroup: this.isGroup,
              workItemType: this.workItemType,
              fullPath: this.fullPath,
              labels: this.visibleLabels.filter(({ id }) => selectedIds.includes(id)),
            },
          },
        });

        this.updateInProgress = false;
        this.addLabelIds = [];
        this.removeLabelIds = [];
        return;
      }

      try {
        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              labelsWidget: {
                addLabelIds: this.addLabelIds,
                removeLabelIds: this.removeLabelIds,
              },
            },
          },
        });

        if (errors.length > 0) {
          throw new Error();
        }

        this.track('updated_labels');
      } catch {
        this.$emit('error', i18n.updateError);
      } finally {
        this.searchTerm = '';
        this.addLabelIds = [];
        this.removeLabelIds = [];
        this.updateInProgress = false;
      }
    },
    scopedLabel(label) {
      return this.allowsScopedLabels && isScopedLabel(label);
    },
    isSelected(id) {
      return this.itemValues.includes(id) || this.addLabelIds.includes(id);
    },
    labelFilterUrl(label) {
      return `${this.issuesListPath}?label_name[]=${encodeURIComponent(label.title)}`;
    },
    handleLabelCreated(label) {
      this.showLabelForm = false;
      this.createdLabelId = label.id;
      this.addLabelIds.push(label.id);
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    :dropdown-label="__('Labels')"
    :can-update="canUpdate"
    :created-label-id="createdLabelId"
    dropdown-name="label"
    :loading="isLoadingLabels"
    :list-items="labelsList"
    :item-value="itemValues"
    :update-in-progress="updateInProgress"
    :toggle-dropdown-text="dropdownText"
    :header-text="__('Select labels')"
    :reset-button-label="__('Clear')"
    show-footer
    multi-select
    clear-search-on-item-select
    data-testid="work-item-labels"
    @dropdownShown="onDropdownShown"
    @searchStarted="search"
    @updateValue="updateLabels"
    @updateSelected="updateLabel"
  >
    <template #list-item="{ item }">
      <span
        :style="{ background: item.color }"
        :class="{ 'gl-border gl-border-white': isSelected(item.value) }"
        class="gl-inline-block gl-rounded gl-mr-1 gl-w-5 gl-h-3 gl-align-middle -gl-mt-1"
      ></span>
      {{ item.text }}
    </template>
    <template #readonly>
      <div class="gl-flex gl-gap-2 gl-flex-wrap gl-mt-1">
        <gl-label
          v-for="label in localLabels"
          :key="label.id"
          :title="label.title"
          :description="label.description"
          :background-color="label.color"
          :scoped="scopedLabel(label)"
          :show-close-button="canUpdate"
          :target="labelFilterUrl(label)"
          @close="removeLabel(label)"
        />
      </div>
    </template>
    <template #footer>
      <gl-button
        v-if="canAdminLabel"
        class="!gl-justify-start"
        block
        category="tertiary"
        data-testid="create-label"
        @click="showLabelForm = true"
      >
        {{ createLabelText }}
      </gl-button>
      <gl-button
        class="!gl-justify-start !gl-mt-2"
        block
        category="tertiary"
        :href="labelsManagePath"
        data-testid="manage-labels"
      >
        {{ manageLabelText }}
      </gl-button>
    </template>
    <template v-if="showLabelForm" #body>
      <gl-disclosure-dropdown
        class="work-item-sidebar-dropdown"
        block
        start-opened
        :toggle-text="dropdownText"
      >
        <div
          class="gl-text-sm gl-font-bold gl-leading-24 gl-border-b gl-pt-2 gl-pb-3 gl-pl-4 gl-mb-4"
        >
          {{ __('Create label') }}
        </div>
        <dropdown-contents-create-view
          class="gl-mb-2"
          :attr-workspace-path="fullPath"
          :full-path="fullPath"
          :label-create-type="workspaceType"
          :search-key="searchTerm"
          :workspace-type="workspaceType"
          @hideCreateView="showLabelForm = false"
          @labelCreated="handleLabelCreated"
        />
      </gl-disclosure-dropdown>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
