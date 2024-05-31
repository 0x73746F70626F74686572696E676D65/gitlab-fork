<script>
import { GlDrawer } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import setActiveBoardItemMutation from 'ee_else_ce/boards/graphql/client/set_active_board_item.mutation.graphql';
import SidebarAncestorsWidget from 'ee_component/sidebar/components/ancestors_tree/sidebar_ancestors_widget.vue';
import { s__ } from '~/locale';
import BoardSidebarTitle from '~/boards/components/sidebar/board_sidebar_title.vue';
import { setError } from '~/boards/graphql/cache_updates';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import SidebarDateWidget from '~/sidebar/components/date/sidebar_date_widget.vue';
import SidebarParticipantsWidget from '~/sidebar/components/participants/sidebar_participants_widget.vue';
import SidebarSubscriptionsWidget from '~/sidebar/components/subscriptions/sidebar_subscriptions_widget.vue';
import SidebarTodoWidget from '~/sidebar/components/todo_toggle/sidebar_todo_widget.vue';
import SidebarLabelsWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ColorSelectDropdown from '~/vue_shared/components/color_select_dropdown/color_select_root.vue';

export default {
  components: {
    BoardSidebarTitle,
    ColorSelectDropdown,
    GlDrawer,
    MountingPortal,
    SidebarAncestorsWidget,
    SidebarConfidentialityWidget,
    SidebarDateWidget,
    SidebarLabelsWidget,
    SidebarParticipantsWidget,
    SidebarSubscriptionsWidget,
    SidebarTodoWidget,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canUpdate', 'labelsFilterBasePath', 'issuableType', 'allowSubEpics'],
  inheritAttrs: false,
  apollo: {
    activeBoardCard: {
      query: activeBoardItemQuery,
      variables: {
        isIssue: false,
      },
      update(data) {
        if (!data.activeBoardItem?.id) {
          return { id: '', iid: '' };
        }
        return data.activeBoardItem;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|An error occurred while selecting the card. Please try again.'),
        });
      },
    },
  },
  computed: {
    isSidebarOpen() {
      return Boolean(this.activeBoardCard?.id);
    },
    fullPath() {
      return this.activeBoardCard?.referencePath?.split('&')[0] || '';
    },
  },
  methods: {
    handleClose() {
      this.$apollo.mutate({
        mutation: setActiveBoardItemMutation,
        variables: {
          boardItem: null,
          listId: null,
        },
      });
    },
  },
};
</script>

<template>
  <mounting-portal mount-to="#js-right-sidebar-portal" name="epic-board-sidebar" append>
    <gl-drawer
      v-bind="$attrs"
      class="boards-sidebar"
      :open="isSidebarOpen"
      variant="sidebar"
      @close="handleClose"
    >
      <template #title>
        <h2 class="gl-my-0 gl-font-size-h2 gl-leading-24">{{ __('Epic details') }}</h2>
      </template>
      <template #header>
        <sidebar-todo-widget
          class="gl-mt-3"
          :issuable-id="activeBoardCard.id"
          :issuable-iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
        />
      </template>
      <template #default>
        <board-sidebar-title :active-item="activeBoardCard" data-testid="sidebar-title" />
        <sidebar-date-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          date-type="startDate"
          :issuable-type="issuableType"
          :can-inherit="true"
        />
        <sidebar-date-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          date-type="dueDate"
          :issuable-type="issuableType"
          :can-inherit="true"
        />
        <sidebar-labels-widget
          class="block labels"
          data-testid="sidebar-labels"
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :allow-label-remove="canUpdate"
          :allow-multiselect="true"
          :labels-filter-base-path="labelsFilterBasePath"
          :attr-workspace-path="fullPath"
          workspace-type="group"
          :issuable-type="issuableType"
          label-create-type="group"
        >
          {{ __('None') }}
        </sidebar-labels-widget>

        <color-select-dropdown
          class="block colors js-colors-block"
          :allow-edit="canUpdate"
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          workspace-type="group"
          issuable-type="epic"
          variant="sidebar"
          data-testid="colors-select"
        >
          {{ __('None') }}
        </color-select-dropdown>

        <sidebar-confidentiality-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
        />
        <sidebar-ancestors-widget
          v-if="allowSubEpics"
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          issuable-type="epic"
        />
        <sidebar-participants-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          issuable-type="epic"
        />
        <sidebar-subscriptions-widget
          :iid="activeBoardCard.iid"
          :full-path="fullPath"
          :issuable-type="issuableType"
          :show-in-dropdown="false"
        />
      </template>
    </gl-drawer>
  </mounting-portal>
</template>
