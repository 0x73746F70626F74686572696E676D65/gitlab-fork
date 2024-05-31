<script>
import { GlModal, GlSprintf, GlLink } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'GroupListItemDeletionDisabledModal',
  i18n: {
    modalTitle: __('Delete group immediately?'),
    topLevelGroupMessage: __(
      '%{group} is a top level group and cannot be immediately deleted from here.  Please visit the %{linkStart}Group Settings%{linkEnd} to immediately delete this group.',
    ),
  },
  components: {
    GlModal,
    GlSprintf,
    GlLink,
  },
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: null,
    },
    modalId: {
      type: String,
      required: true,
    },
    group: {
      type: Object,
      required: true,
    },
  },
  CANCEL_PROPS: {
    text: __('Cancel'),
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    :visible="visible"
    :modal-id="modalId"
    :data-testid="modalId"
    :title="$options.i18n.modalTitle"
    size="sm"
    :action-cancel="$options.CANCEL_PROPS"
    @change="$emit('change', $event)"
  >
    <slot name="modal-body">
      <gl-sprintf :message="$options.i18n.topLevelGroupMessage">
        <template #group
          ><span class="gl-font-bold">{{ group.name }}</span></template
        >
        <template #link="{ content }">
          <gl-link :href="group.editPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </slot>
  </gl-modal>
</template>
