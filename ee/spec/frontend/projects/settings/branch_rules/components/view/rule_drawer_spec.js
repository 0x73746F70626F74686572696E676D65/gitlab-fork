import { nextTick } from 'vue';
import { GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleDrawer from '~/projects/settings/branch_rules/components/view/rule_drawer.vue';
import ItemsSelector from 'ee_component/projects/settings/branch_rules/components/view/items_selector.vue';
import { allowedToMergeDrawerProps } from './mock_data';

describe('Edit Rule Drawer', () => {
  let wrapper;

  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findUsersSelector = () => wrapper.findByTestId('users-selector');
  const findGroupsSelector = () => wrapper.findByTestId('groups-selector');
  const findSaveButton = () => wrapper.findByText('Save changes');

  const createComponent = (props = allowedToMergeDrawerProps) => {
    wrapper = shallowMountExtended(RuleDrawer, {
      components: { ItemsSelector },
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('isOpen watcher', () => {
    beforeEach(() => createComponent({ ...allowedToMergeDrawerProps, roles: [30, 40, 60] }));

    it('renders drawer all checkboxes unchecked by default', () => {
      findCheckboxes().wrappers.forEach((checkbox) =>
        expect(checkbox.attributes('checked')).toBeUndefined(),
      );
    });

    it('updates the checkboxes to the correct state when isOpen is changed', async () => {
      wrapper.setProps({ isOpen: true }); // simulates the drawer being opened from the parent
      await nextTick();

      findCheckboxes().wrappers.forEach((checkbox) =>
        expect(checkbox.attributes('checked')).toBe('true'),
      );
    });
  });

  it('Renders Item Selector with  users', () => {
    expect(findUsersSelector().props('items')).toMatchObject([
      {
        __typename: 'UserCore',
        avatarUrl: 'test.com/user.png',
        id: 123,
        name: 'peter',
        src: 'test.com/user.png',
        webUrl: 'test.com',
      },
    ]);
  });

  it('Renders Item Selector with groups', () => {
    expect(findGroupsSelector().props('items')).toMatchObject([]);
  });

  it('enables the save button when users or groups are selected', async () => {
    findUsersSelector().vm.$emit('change', ['some data']);
    await nextTick();
    expect(findSaveButton().attributes('disabled')).toBeUndefined();
  });
});
