import { shallowMount } from '@vue/test-utils';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import EEWorkItemsListApp from 'ee/work_items/list/components/work_items_list_app.vue';

describe('WorkItemsListApp EE component', () => {
  let wrapper;

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);

  const mountComponent = ({ hasEpicsFeature = false } = {}) => {
    wrapper = shallowMount(EEWorkItemsListApp, {
      provide: {
        hasEpicsFeature,
      },
    });
  };

  it('renders create work item modal when epics feature available', () => {
    mountComponent({ hasEpicsFeature: true });

    expect(findCreateWorkItemModal().props()).toEqual({
      workItemTypeName: 'EPIC',
      asDropdownItem: false,
    });
  });

  it('does not render modal when epics feature not available', () => {
    mountComponent({ hasEpicsFeature: false });

    expect(findCreateWorkItemModal().exists()).toBe(false);
  });
});
