import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import CustomRolesActions from 'ee/roles_and_permissions/components/custom_roles_actions.vue';
import { visitUrl } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility');

describe('CustomRolesActions', () => {
  let wrapper;

  const mockCustomRole = { membersCount: 0, editPath: 'edit/path' };

  const createComponent = ({ customRole = mockCustomRole } = {}) => {
    wrapper = mountExtended(CustomRolesActions, {
      propsData: { customRole },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItem = (index) =>
    findDropdown().findAllComponents(GlDisclosureDropdownItem).at(index);

  const findEditRole = () => findDropdownItem(0);
  const findDeleteRole = () => findDropdownItem(1);

  beforeEach(() => {
    createComponent();
  });

  it('renders the actions dropdown', () => {
    expect(findDropdown().exists()).toBe(true);

    expect(findDropdown().props()).toMatchObject({
      icon: 'ellipsis_v',
      category: 'tertiary',
      placement: 'bottom-end',
    });
  });

  describe('edit role', () => {
    it('renders the edit role action item', () => {
      expect(findEditRole().props('item')).toMatchObject({ text: 'Edit role' });
    });

    it('goes to the edit page when clicked', () => {
      findEditRole().vm.$emit('action');

      expect(visitUrl).toHaveBeenCalledWith('edit/path');
    });
  });

  describe('delete role', () => {
    it('renders the delete role action item', () => {
      expect(findDeleteRole().props('item')).toMatchObject({
        text: 'Delete role',
        extraAttrs: { class: 'gl-text-red-500!' },
      });
    });

    it('emits `delete` event when delete role is clicked', async () => {
      await findDeleteRole().find('button').trigger('click');

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    describe('when `membersCount` of a custom role is greater than 0', () => {
      beforeEach(() => {
        createComponent({ customRole: { membersCount: 1 } });
      });

      it('disables the delete role action item', () => {
        expect(findDeleteRole().props('item').extraAttrs.disabled).toBe(true);
      });
    });
  });
});
