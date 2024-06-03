import { GlDrawer, GlBadge, GlSprintf, GlIcon } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import axios from 'axios';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleDetailsDrawer from '~/members/components/table/role_details_drawer.vue';
import MembersTableCell from '~/members/components/table/members_table_cell.vue';
import RoleSelector from '~/members/components/table/role_selector.vue';
import { roleDropdownItems } from 'ee/members/utils';
import waitForPromises from 'helpers/wait_for_promises';
import { member as baseRoleMember, updateableCustomRoleMember } from '../../mock_data';

describe('Role details drawer', () => {
  const { permissions } = updateableCustomRoleMember.customRoles[1];
  const customRole = roleDropdownItems(updateableCustomRoleMember).flatten[8];
  let axiosMock;
  let wrapper;

  const createWrapper = ({ member = updateableCustomRoleMember, namespace = 'user' } = {}) => {
    wrapper = shallowMountExtended(RoleDetailsDrawer, {
      propsData: { member, memberPath: 'user/path/:id' },
      provide: {
        currentUserId: 1,
        canManageMembers: true,
        namespace,
      },
      stubs: { GlDrawer, MembersTableCell, GlSprintf },
    });
  };

  const findRoleSelector = () => wrapper.findComponent(RoleSelector);
  const findCustomRoleBadge = () => wrapper.findComponent(GlBadge);
  const findDescriptionHeader = () => wrapper.findByTestId('description-header');
  const findDescriptionValue = () => wrapper.findByTestId('description-value');
  const findBaseRole = () => wrapper.findByTestId('base-role');
  const findPermissions = () => wrapper.findAllByTestId('permission');
  const findPermissionAt = (index) => findPermissions().at(index);
  const findPermissionNameAt = (index) => wrapper.findAllByTestId('permission-name').at(index);
  const findPermissionDescriptionAt = (index) =>
    wrapper.findAllByTestId('permission-description').at(index);
  const findSaveButton = () => wrapper.findByTestId('save-button');

  const createWrapperChangeRoleAndClickSave = async () => {
    createWrapper({ member: updateableCustomRoleMember });
    findRoleSelector().vm.$emit('input', customRole);
    await nextTick();
    findSaveButton().vm.$emit('click');

    return waitForPromises();
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('when the member has a base role', () => {
    beforeEach(() => {
      createWrapper({ member: baseRoleMember });
    });

    it('does not show the custom role badge', () => {
      expect(findCustomRoleBadge().exists()).toBe(false);
    });

    it('does not show the role description', () => {
      expect(findDescriptionHeader().exists()).toBe(false);
      expect(findDescriptionValue().exists()).toBe(false);
    });

    it('does not show the base role in the permissions section', () => {
      expect(findBaseRole().exists()).toBe(false);
    });

    it('does not show any permissions', () => {
      expect(findPermissions()).toHaveLength(0);
    });
  });

  describe('when the member has a custom role', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the custom role badge', () => {
      expect(findCustomRoleBadge().props('size')).toBe('sm');
      expect(findCustomRoleBadge().text()).toBe('Custom role');
    });

    it('shows the role description', () => {
      expect(findDescriptionHeader().text()).toBe('Description');
      expect(findDescriptionValue().text()).toBe('custom role 1 description');
    });

    it('shows the base role in the permissions section', () => {
      expect(findBaseRole().text()).toMatchInterpolatedText('Base role: Guest');
    });

    it('shows the expected number of permissions', () => {
      expect(findPermissions()).toHaveLength(2);
    });

    describe.each(permissions)(`for permission '$name'`, (permission) => {
      const index = permissions.indexOf(permission);

      it('shows the check icon', () => {
        expect(findPermissionAt(index).findComponent(GlIcon).props('name')).toBe('check');
      });

      it('shows the permission name', () => {
        expect(findPermissionNameAt(index).text()).toBe(`Permission ${index}`);
      });

      it('shows the permission description', () => {
        expect(findPermissionDescriptionAt(index).text()).toBe(`Permission description ${index}`);
      });
    });
  });

  describe('when update role button is clicked for a custom role', () => {
    beforeEach(() => {
      axiosMock.onPut('user/path/238').replyOnce(200);
      return createWrapperChangeRoleAndClickSave();
    });

    it('calls update role API with expected data', () => {
      const expectedData = JSON.stringify({ access_level: 10, member_role_id: 102 });

      expect(axiosMock.history.put[0].data).toBe(expectedData);
    });
  });
});
