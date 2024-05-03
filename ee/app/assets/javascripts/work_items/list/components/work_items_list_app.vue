<script>
import { WORK_ITEM_TYPE_ENUM_EPIC } from '~/work_items/constants';
import WorkItemsListApp from '~/work_items/list/components/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';

export default {
  WORK_ITEM_TYPE_ENUM_EPIC,
  components: {
    CreateWorkItemModal,
    WorkItemsListApp,
  },
  inject: ['hasEpicsFeature'],
  data() {
    return {
      showEpicCreationForm: false,
    };
  },
  methods: {
    handleCreated({ workItem }) {
      if (workItem.id) {
        // Refresh results on list
        this.showEpicCreationForm = false;
        this.$refs.workItemsListApp.$apollo.queries.workItems.refetch();
      }
    },
  },
};
</script>

<template>
  <work-items-list-app ref="workItemsListApp">
    <template v-if="hasEpicsFeature" #nav-actions>
      <create-work-item-modal
        class="gl-flex-grow-1"
        :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
      />
    </template>
  </work-items-list-app>
</template>
