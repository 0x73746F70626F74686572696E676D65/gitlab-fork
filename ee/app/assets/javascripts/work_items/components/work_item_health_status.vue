<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
} from 'ee/sidebar/constants';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  sprintfWorkItem,
  TRACKING_CATEGORY_SHOW,
} from '~/work_items/constants';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import { newWorkItemId } from '~/work_items/utils';
import Tracking from '~/tracking';

export default {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS,
  healthStatusDropdownOptions,
  components: {
    IssueHealthStatus,
    WorkItemSidebarDropdownWidget,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIssuableHealthStatusFeature', 'isGroup'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    healthStatus: {
      type: String,
      required: false,
      default: null,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
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
  },
  data() {
    return {
      updateInProgress: false,
    };
  },
  computed: {
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: `type_${this.workItemType}`,
      };
    },
    dropdownItems() {
      const emptyItem = {
        text: this.$options.HEALTH_STATUS_I18N_NO_STATUS,
        value: null,
      };
      return [emptyItem, ...healthStatusDropdownOptions];
    },
    selectedHealthStatus() {
      return this.healthStatus || null;
    },
  },
  methods: {
    updateHealthStatus(healthStatus) {
      if (!this.canUpdate) {
        return;
      }

      this.track('updated_health_status');

      this.updateInProgress = true;

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$apollo.mutate({
          mutation: updateNewWorkItemMutation,
          variables: {
            input: {
              isGroup: this.isGroup,
              fullPath: this.fullPath,
              healthStatus,
              workItemType: this.workItemType,
            },
          },
        });
        this.updateInProgress = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              healthStatusWidget: {
                healthStatus,
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
  },
};
</script>

<template>
  <div v-if="hasIssuableHealthStatusFeature">
    <work-item-sidebar-dropdown-widget
      :dropdown-label="$options.HEALTH_STATUS_I18N_HEALTH_STATUS"
      :can-update="canUpdate"
      dropdown-name="health-status"
      :list-items="$options.healthStatusDropdownOptions"
      :item-value="selectedHealthStatus"
      :header-text="$options.HEALTH_STATUS_I18N_SELECT_HEALTH_STATUS"
      :update-in-progress="updateInProgress"
      :reset-button-label="__('Clear')"
      :searchable="false"
      data-testid="work-item-health-status"
      @updateValue="updateHealthStatus"
    >
      <template #readonly>
        <issue-health-status
          data-testid="work-item-health-status-value"
          :health-status="selectedHealthStatus"
        />
      </template>
    </work-item-sidebar-dropdown-widget>
  </div>
</template>
