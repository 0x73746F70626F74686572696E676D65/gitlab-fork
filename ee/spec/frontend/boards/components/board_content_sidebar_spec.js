import { GlDrawer } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardContentSidebar from '~/boards/components/board_content_sidebar.vue';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import SidebarAssigneesWidget from '~/sidebar/components/assignees/sidebar_assignees_widget.vue';
import SidebarLabelsWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import { identifyAffectedLists } from '~/boards/graphql/cache_updates';
import { TYPE_ISSUE } from '~/issues/constants';
import { rawIssue } from '../mock_data';

jest.mock('~/boards/graphql/cache_updates', () => ({
  identifyAffectedLists: jest.fn(() => ['gid://gitlab/List/3']),
}));

Vue.use(VueApollo);

describe('ee/BoardContentSidebar', () => {
  let wrapper;

  const mockSetActiveBoardItemResolver = jest.fn();
  const mockApollo = createMockApollo([], {
    Mutation: {
      setActiveBoardItem: mockSetActiveBoardItemResolver,
    },
  });

  const setPortalAnchorPoint = () => {
    const el = document.createElement('div');
    el.setAttribute('id', 'js-right-sidebar-portal');
    document.body.appendChild(el);
  };

  const createComponent = ({ issuable = rawIssue } = {}) => {
    setPortalAnchorPoint();

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: activeBoardItemQuery,
      data: {
        activeBoardItem: { ...issuable, listId: 'gid://gitlab/List/1' },
      },
    });

    wrapper = shallowMountExtended(BoardContentSidebar, {
      apolloProvider: mockApollo,
      provide: {
        canUpdate: true,
        rootPath: '/',
        groupId: 1,
        issuableType: TYPE_ISSUE,
        isGroupBoard: false,
        epicFeatureAvailable: true,
        iterationFeatureAvailable: true,
        weightFeatureAvailable: true,
        healthStatusFeatureAvailable: true,
      },
      propsData: {
        backlogListId: 'gid://gitlab/List/1',
        closedListId: 'gid://gitlab/List/2',
      },
      stubs: {
        GlDrawer: stubComponent(GlDrawer, {
          template: `
            <div>
              <slot name="title"></slot>
              <slot name="header"></slot>
              <slot></slot>
            </div>`,
        }),
      },
    });
  };

  describe('issue sidebar', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('matches the snapshot', () => {
      expect(wrapper.findComponent(GlDrawer).element).toMatchSnapshot();
    });
  });

  describe('incident sidebar', () => {
    beforeEach(async () => {
      createComponent({ issuable: { ...rawIssue, epic: null, type: 'INCIDENT' } });
      await waitForPromises();
    });

    it('matches the snapshot', () => {
      expect(wrapper.findComponent(GlDrawer).element).toMatchSnapshot();
    });
  });

  describe('when child widgets emit events', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('adds assignee list ID and type to the affected lists', async () => {
      const updatedId = 'gid://gitlab/UserCore/1';

      wrapper
        .findComponent(SidebarAssigneesWidget)
        .vm.$emit('assignees-updated', { assignees: [{ id: updatedId }] });

      wrapper.findComponent(GlDrawer).vm.$emit('close');
      await waitForPromises();

      expect(identifyAffectedLists).toHaveBeenCalledWith(
        expect.objectContaining({
          updatedAttributeIds: [updatedId],
          affectedListTypes: ['assignee'],
        }),
      );
    });

    it('adds label list ID and type to the affected lists', async () => {
      const updatedId = 'gid://gitlab/Label/1';

      wrapper
        .findComponent(SidebarLabelsWidget)
        .vm.$emit('updateSelectedLabels', { labels: [{ id: updatedId }] });

      wrapper.findComponent(GlDrawer).vm.$emit('close');
      await waitForPromises();

      expect(identifyAffectedLists).toHaveBeenCalledWith(
        expect.objectContaining({
          updatedAttributeIds: [updatedId],
          affectedListTypes: ['label'],
        }),
      );
    });

    it('adds milestone list ID and type to the affected lists', async () => {
      const updatedId = 'gid://gitlab/Milestone/1';
      const updatedAttribute = {
        issuableSetAttribute: {
          issuable: {
            attribute: {
              id: updatedId,
            },
          },
        },
      };

      wrapper.findByTestId('sidebar-milestones').vm.$emit('attribute-updated', updatedAttribute);

      wrapper.findComponent(GlDrawer).vm.$emit('close');
      await waitForPromises();

      expect(identifyAffectedLists).toHaveBeenCalledWith(
        expect.objectContaining({
          updatedAttributeIds: [updatedId],
          affectedListTypes: ['milestone'],
        }),
      );
    });

    it('adds iteration list ID and type to the affected lists', async () => {
      const updatedId = 'gid://gitlab/Iteration/1';
      const updatedAttribute = {
        issuableSetAttribute: {
          issuable: {
            attribute: {
              id: updatedId,
            },
          },
        },
      };

      wrapper.findByTestId('iteration-edit').vm.$emit('iteration-updated', updatedAttribute);

      wrapper.findComponent(GlDrawer).vm.$emit('close');
      await waitForPromises();

      expect(identifyAffectedLists).toHaveBeenCalledWith(
        expect.objectContaining({
          updatedAttributeIds: [updatedId],
          affectedListTypes: ['iteration'],
        }),
      );
    });
  });
});
