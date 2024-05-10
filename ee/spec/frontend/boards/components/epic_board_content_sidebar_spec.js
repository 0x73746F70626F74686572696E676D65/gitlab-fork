import { GlDrawer } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import activeBoardItemQuery from 'ee_component/boards/graphql/client/active_board_item.query.graphql';
import EpicBoardContentSidebar from 'ee_component/boards/components/epic_board_content_sidebar.vue';
import SidebarAncestorsWidget from 'ee_component/sidebar/components/ancestors_tree/sidebar_ancestors_widget.vue';
import { stubComponent } from 'helpers/stub_component';
import BoardSidebarTitle from '~/boards/components/sidebar/board_sidebar_title.vue';
import { TYPE_EPIC } from '~/issues/constants';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import SidebarDateWidget from '~/sidebar/components/date/sidebar_date_widget.vue';
import SidebarParticipantsWidget from '~/sidebar/components/participants/sidebar_participants_widget.vue';
import SidebarSubscriptionsWidget from '~/sidebar/components/subscriptions/sidebar_subscriptions_widget.vue';
import SidebarTodoWidget from '~/sidebar/components/todo_toggle/sidebar_todo_widget.vue';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import ColorSelectDropdown from '~/vue_shared/components/color_select_dropdown/color_select_root.vue';
import { rawEpic } from '../mock_data';

Vue.use(VueApollo);

describe('EpicBoardContentSidebar', () => {
  let wrapper;

  const mockSetActiveBoardItemResolver = jest.fn();
  const mockApollo = createMockApollo([], {
    Mutation: {
      setActiveBoardItem: mockSetActiveBoardItemResolver,
    },
  });

  const createComponent = ({ glFeatures = {}, issuable = rawEpic, allowSubEpics = false } = {}) => {
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: activeBoardItemQuery,
      variables: {
        isIssue: false,
      },
      data: {
        activeBoardItem: { ...issuable, listId: 'gid://gitlab/List/1' },
      },
    });

    wrapper = shallowMountExtended(EpicBoardContentSidebar, {
      apolloProvider: mockApollo,
      provide: {
        canUpdate: true,
        rootPath: '/',
        groupId: 1,
        issuableType: TYPE_EPIC,
        labelsFilterBasePath: '',
        allowSubEpics,
        glFeatures,
      },
      stubs: {
        GlDrawer: stubComponent(GlDrawer, {
          template: '<div><slot name="header"></slot><slot></slot></div>',
        }),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('confirms we render GlDrawer', () => {
    expect(wrapper.findComponent(GlDrawer).exists()).toBe(true);
  });

  it('confirms we render MountingPortal', () => {
    expect(wrapper.findComponent(MountingPortal).props()).toMatchObject({
      mountTo: '#js-right-sidebar-portal',
      append: true,
      name: 'epic-board-sidebar',
    });
  });

  it('does not render GlDrawer when no active item is set', () => {
    createComponent({ issuable: {} });

    expect(wrapper.findComponent(GlDrawer).props('open')).toBe(false);
  });

  it('applies an open attribute', () => {
    expect(wrapper.findComponent(GlDrawer).props('open')).toBe(true);
  });

  it('renders SidebarTodoWidget passing correct epic fullPath', () => {
    expect(wrapper.findComponent(SidebarTodoWidget).exists()).toBe(true);
    expect(wrapper.findComponent(SidebarTodoWidget).props('fullPath')).toBe(
      'gitlab-org/gitlab-subgroup',
    );
  });

  it('renders LabelsSelectWidget', () => {
    expect(wrapper.findComponent(LabelsSelectWidget).exists()).toBe(true);
  });

  it('renders ColorDropdownSelect in the sidebar', () => {
    createComponent();
    expect(wrapper.findComponent(ColorSelectDropdown).exists()).toBe(true);
  });

  it('renders BoardSidebarTitle', () => {
    expect(wrapper.findComponent(BoardSidebarTitle).exists()).toBe(true);
  });

  it('renders SidebarConfidentialityWidget', () => {
    expect(wrapper.findComponent(SidebarConfidentialityWidget).exists()).toBe(true);
  });

  it('renders 2 SidebarDateWidget', () => {
    expect(wrapper.findAllComponents(SidebarDateWidget)).toHaveLength(2);
  });

  it('renders SidebarParticipantsWidget', () => {
    expect(wrapper.findComponent(SidebarParticipantsWidget).exists()).toBe(true);
  });

  it('renders SidebarSubscriptionsWidget', () => {
    expect(wrapper.findComponent(SidebarSubscriptionsWidget).exists()).toBe(true);
  });

  it('does not render SidebarAncestorsWidget', () => {
    expect(wrapper.findComponent(SidebarAncestorsWidget).exists()).toBe(false);
  });

  it('renders SidebarAncestorsWidget when allowSubEpics is true', () => {
    createComponent({
      allowSubEpics: true,
    });

    expect(wrapper.findComponent(SidebarAncestorsWidget).exists()).toBe(true);
  });

  describe('when we emit close', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls setActiveBoardItemMutation on close', async () => {
      wrapper.findComponent(GlDrawer).vm.$emit('close');

      await waitForPromises();

      expect(mockSetActiveBoardItemResolver).toHaveBeenCalledWith(
        {},
        {
          boardItem: null,
          listId: null,
        },
        expect.anything(),
        expect.anything(),
      );
    });
  });
});
