import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleDrawer from '~/projects/settings/branch_rules/components/view/rule_drawer.vue';
import ItemsSelector from 'ee_component/projects/settings/branch_rules/components/view/items_selector.vue';
import { allowedToMergeDrawerProps } from './mock_data';

describe('Edit Rule Drawer', () => {
  let wrapper;

  const findItemsSelector = () => wrapper.findComponent(ItemsSelector);
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

  it('Renders Item Selector with  users', () => {
    expect(findItemsSelector().props('items')).toMatchObject([
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

  it('enables the save button when users or groups are selected', async () => {
    findItemsSelector().vm.$emit('change', ['some data']);
    await nextTick();
    expect(findSaveButton().attributes('disabled')).toBeUndefined();
  });
});
