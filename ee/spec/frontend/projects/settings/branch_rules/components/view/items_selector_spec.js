import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListSelector from '~/vue_shared/components/list_selector/index.vue';
import ItemsSelector from 'ee_component/projects/settings/branch_rules/components/view/items_selector.vue';
import { usersMock } from './mock_data';

describe('Items selector component', () => {
  let wrapper;
  const items = usersMock;

  const findListSelector = () => wrapper.findComponent(ListSelector);

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ItemsSelector, {
      propsData: {
        items,
        type: 'user',
        ...propsData,
      },
    });
  };

  it('renders the list selector component', () => {
    createComponent();
    expect(findListSelector().exists()).toBe(true);
  });

  it('passes the correct props to the list selector component', () => {
    createComponent({
      usersOptions: { active: true },
      disableNamespaceDropdown: true,
    });

    expect(findListSelector().props('type')).toBe('user');
    expect(findListSelector().props('selectedItems')).toEqual(items);
    expect(findListSelector().props('usersQueryOptions')).toEqual({ active: true });
    expect(findListSelector().props('disableNamespaceDropdown')).toBe(true);
  });

  it('emits the change event with the updated selectedItems when an item is selected', async () => {
    createComponent();
    const listSelectorComponent = wrapper.findComponent(ListSelector);
    const newItem = { id: 3, name: 'Item 3' };

    await listSelectorComponent.vm.$emit('select', newItem);

    expect(wrapper.emitted('change')).toEqual([[items.concat(newItem)]]);
  });

  it('emits the change event with the updated selectedItems when an item is deleted', async () => {
    createComponent();
    const listSelectorComponent = wrapper.findComponent(ListSelector);
    await listSelectorComponent.vm.$emit('delete', '123');
    expect(wrapper.emitted('change')).toEqual([[items.slice(1)]]);
  });
});
