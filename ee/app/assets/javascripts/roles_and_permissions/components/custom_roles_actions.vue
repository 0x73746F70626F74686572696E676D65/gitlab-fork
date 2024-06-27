<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';

export default {
  i18n: {
    actionsText: s__('MemberRole|Actions'),
    editRoleText: s__('MemberRole|Edit role'),
    deleteRoleText: s__('MemberRole|Delete role'),
    deleteDisabledTooltip: s__(
      'MemberRole|To delete custom role, remove role from all group members.',
    ),
  },
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    customRole: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasAssignedUsers() {
      return this.customRole.membersCount > 0;
    },
    editRoleItem() {
      return { text: this.$options.i18n.editRoleText };
    },
    deleteRoleItem() {
      return {
        text: this.$options.i18n.deleteRoleText,
        action: () => this.$emit('delete'),
        extraAttrs: {
          disabled: this.hasAssignedUsers,
          class: this.hasAssignedUsers ? '' : 'gl-text-red-500!',
        },
      };
    },
    deleteTooltip() {
      return this.hasAssignedUsers ? this.$options.i18n.deleteDisabledTooltip : '';
    },
  },
  methods: {
    navigateToEditPage() {
      visitUrl(this.customRole.editPath);
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    v-gl-tooltip.hover.top.viewport="$options.i18n.actionsText"
    category="tertiary"
    icon="ellipsis_v"
    placement="bottom-end"
    no-caret
    text-sr-only
    :toggle-text="$options.i18n.actionsText"
  >
    <gl-disclosure-dropdown-item :item="editRoleItem" @action="navigateToEditPage" />
    <gl-disclosure-dropdown-item
      v-gl-tooltip.left.viewport.d0="deleteTooltip"
      :item="deleteRoleItem"
    />
  </gl-disclosure-dropdown>
</template>
