<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { TYPE_INCIDENT, TYPE_ISSUE } from '~/issues/constants';
import eventHub from '../event_hub';

export default {
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  inject: ['issuableType'],
  computed: {
    showConvertToTaskItem() {
      return [TYPE_INCIDENT, TYPE_ISSUE].includes(this.issuableType);
    },
  },
  methods: {
    convertToTask() {
      eventHub.$emit('convert-task-list-item', this.$el.closest('li').dataset.sourcepos);
    },
    deleteTaskListItem() {
      eventHub.$emit('delete-task-list-item', this.$el.closest('li').dataset.sourcepos);
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    class="task-list-item-actions-wrapper"
    category="tertiary"
    icon="ellipsis_v"
    no-caret
    placement="bottom-end"
    text-sr-only
    toggle-class="task-list-item-actions gl-opacity-0 !gl-p-2"
    :toggle-text="s__('WorkItem|Task actions')"
  >
    <gl-disclosure-dropdown-item
      v-if="showConvertToTaskItem"
      class="!gl-ml-2"
      data-testid="convert"
      @action="convertToTask"
    >
      <template #list-item>
        {{ s__('WorkItem|Convert to task') }}
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item class="!gl-ml-2" data-testid="delete" @action="deleteTaskListItem">
      <template #list-item>
        <span class="gl-text-red-500">{{ __('Delete') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
</template>
