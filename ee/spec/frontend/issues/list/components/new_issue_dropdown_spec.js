import { GlButton, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import NewIssueDropdown from 'ee/issues/list/components/new_issue_dropdown.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import { WORK_ITEM_TYPE_ENUM_OBJECTIVE } from '~/work_items/constants';

const NEW_ISSUE_PATH = 'mushroom-kingdom/~/issues/new';

describe('NewIssueDropdown component', () => {
  let wrapper;

  const createComponent = () => {
    return mount(NewIssueDropdown, {
      provide: {
        newIssuePath: NEW_ISSUE_PATH,
        fullPath: 'full-path',
        isGroup: false,
      },
      stubs: {
        CreateWorkItemModal,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItem = (index) =>
    findDropdown().findAllComponents(GlDisclosureDropdownItem).at(index);
  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders a split dropdown with newIssue label', () => {
    expect(findButton().text()).toBe('New issue');
    expect(findButton().attributes('href')).toBe(NEW_ISSUE_PATH);
  });

  it('renders dropdown with New Issue item', () => {
    expect(findDropdownItem(0).props().item).toMatchObject({
      text: 'New issue',
      href: NEW_ISSUE_PATH,
    });
  });

  it('renders findCreateWorkItemModal as dropdown item for objectives', () => {
    expect(findCreateWorkItemModal().props()).toMatchObject({
      asDropdownItem: true,
      workItemTypeName: WORK_ITEM_TYPE_ENUM_OBJECTIVE,
    });
  });
});
