import { GlEmptyState } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/list/components/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/list/components/work_items_list_app.vue';

describe('WorkItemsListApp EE component', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
  const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
  const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);

  const mountComponent = ({ hasEpicsFeature = true, showNewIssueLink = true } = {}) => {
    wrapper = shallowMount(EEWorkItemsListApp, {
      provide: {
        hasEpicsFeature,
        showNewIssueLink,
      },
    });
  };

  describe('create-work-item modal', () => {
    describe.each`
      hasEpicsFeature | showNewIssueLink | exists
      ${false}        | ${false}         | ${false}
      ${true}         | ${false}         | ${false}
      ${false}        | ${true}          | ${false}
      ${true}         | ${true}          | ${true}
    `(
      'when hasEpicsFeature=$hasEpicsFeature and showNewIssueLink=$showNewIssueLink',
      ({ hasEpicsFeature, showNewIssueLink, exists }) => {
        it(`${exists ? 'renders' : 'does not render'}`, () => {
          mountComponent({ hasEpicsFeature, showNewIssueLink });

          expect(findCreateWorkItemModal().exists()).toBe(exists);
        });
      },
    );

    describe('when "workItemCreated" event is emitted', () => {
      it('increments `eeCreatedWorkItemsCount` prop on WorkItemsListApp', async () => {
        mountComponent();

        expect(findWorkItemsListApp().props('eeCreatedWorkItemsCount')).toBe(0);

        findCreateWorkItemModal().vm.$emit('workItemCreated');
        await nextTick();

        expect(findWorkItemsListApp().props('eeCreatedWorkItemsCount')).toBe(1);
      });
    });
  });

  describe('empty states', () => {
    describe('when hasEpicsFeature=true', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: true });
      });

      it('renders list empty state', () => {
        expect(findListEmptyState().props()).toEqual({
          hasSearch: false,
          isEpic: true,
          isOpenTab: true,
        });
      });

      it('renders page empty state', () => {
        expect(wrapper.findComponent(GlEmptyState).props()).toMatchObject({
          description: 'Track groups of issues that share a theme, across projects and milestones',
          title:
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
        });
      });
    });

    describe('when hasEpicsFeature=false', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: false });
      });

      it('does not render list empty state', () => {
        expect(findListEmptyState().exists()).toBe(false);
      });

      it('does not render page empty state', () => {
        expect(findPageEmptyState().exists()).toBe(false);
      });
    });
  });
});
