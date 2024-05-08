import { GlTable, GlFormCheckbox, GlAlert, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import PermissionsSelector, {
  FIELDS,
} from 'ee/roles_and_permissions/components/permissions_selector.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import memberRolePermissionsQuery from 'ee/roles_and_permissions/graphql/member_role_permissions.query.graphql';
import { mockPermissions, mockDefaultPermissions } from '../mock_data';

Vue.use(VueApollo);

describe('Permissions Selector component', () => {
  let wrapper;

  const defaultAvailablePermissionsHandler = jest.fn().mockResolvedValue(mockPermissions);
  const glTableStub = stubComponent(GlTable, { props: ['items', 'fields', 'busy'] });

  const createComponent = ({
    mountFn = shallowMountExtended,
    permissions = [],
    isValid = true,
    baseRoleAccessLevel = 30,
    availablePermissionsHandler = defaultAvailablePermissionsHandler,
  } = {}) => {
    wrapper = mountFn(PermissionsSelector, {
      propsData: { permissions, isValid, baseRoleAccessLevel },
      apolloProvider: createMockApollo([[memberRolePermissionsQuery, availablePermissionsHandler]]),
      stubs: {
        GlSprintf,
        ...(mountFn === shallowMountExtended ? { GlTable: glTableStub } : {}),
      },
    });

    return waitForPromises();
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findPermissionsSelectedMessage = () => wrapper.findByTestId('permissions-selected-message');
  const findAlert = () => wrapper.findComponent(GlAlert);

  const checkPermission = (value) => {
    findTable().vm.$emit('row-clicked', { value });
  };

  const expectSelectedPermissions = (expected) => {
    const permissions = wrapper.emitted('change') == null ? [] : wrapper.emitted('change')[0][0];

    expect(permissions.sort()).toEqual(expected.sort());
  };

  describe('available permissions', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('calls the query', () => {
        expect(defaultAvailablePermissionsHandler).toHaveBeenCalledTimes(1);
      });

      it('shows the table as busy', () => {
        expect(findTable().props('busy')).toBe(true);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });

      it('does not show the error message', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('after data is loaded', () => {
      describe('before a base role is selected', () => {
        beforeEach(() => {
          return createComponent({ baseRoleAccessLevel: null });
        });

        it('does not show the table with the expected permissions', () => {
          expect(findTable().exists()).toBe(false);
        });

        it('does not show the permissions selected message', () => {
          expect(findPermissionsSelectedMessage().exists()).toBe(false);
        });

        it('does not show the error message', () => {
          expect(findAlert().exists()).toBe(false);
        });
      });

      describe('after a base role is selected', () => {
        beforeEach(() => {
          return createComponent();
        });

        it('shows the table with the expected permissions', () => {
          expect(findTable().props('busy')).toBe(false);
          expect(findTable().props()).toMatchObject({
            fields: FIELDS,
            items: mockDefaultPermissions,
          });
        });

        it('shows the permissions selected message', () => {
          expect(findPermissionsSelectedMessage().text()).toBe(
            `1 of ${mockDefaultPermissions.length} permissions selected`,
          );
        });

        it('does not show the error message', () => {
          expect(findAlert().exists()).toBe(false);
        });
      });
    });

    describe('on query error', () => {
      beforeEach(() => {
        const availablePermissionsHandler = jest.fn().mockRejectedValue();
        return createComponent({ availablePermissionsHandler });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('Could not fetch available permissions.');
      });

      it('does not show the table', () => {
        expect(findTable().exists()).toBe(false);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });
    });
  });

  describe('dependent permissions', () => {
    it.each`
      permission | expected
      ${'A'}     | ${['A']}
      ${'B'}     | ${['A', 'B']}
      ${'C'}     | ${['A', 'B', 'C']}
      ${'D'}     | ${['A', 'B', 'C', 'D']}
      ${'E'}     | ${['E', 'F']}
      ${'F'}     | ${['E', 'F']}
      ${'G'}     | ${['A', 'B', 'C', 'G']}
      ${'H'}     | ${[]}
    `('selects $expected when $permission is selected', async ({ permission, expected }) => {
      await createComponent();
      checkPermission(permission);

      expectSelectedPermissions(expected);
    });

    it.each`
      permission | expected
      ${'A'}     | ${['E', 'F', 'H']}
      ${'B'}     | ${['A', 'E', 'F', 'H']}
      ${'C'}     | ${['A', 'B', 'E', 'F', 'H']}
      ${'D'}     | ${['A', 'B', 'C', 'E', 'F', 'G', 'H']}
      ${'E'}     | ${['A', 'B', 'C', 'D', 'G', 'H']}
      ${'F'}     | ${['A', 'B', 'C', 'D', 'G', 'H']}
      ${'G'}     | ${['A', 'B', 'C', 'D', 'E', 'F', 'H']}
    `(
      'selects $expected when all permissions start off selected and $permission is unselected',
      async ({ permission, expected }) => {
        const permissions = mockDefaultPermissions.map((p) => p.value);
        await createComponent({ permissions });
        // Uncheck the permission by removing it from all permissions.
        checkPermission(permission);

        expectSelectedPermissions(expected);
      },
    );

    it('checks the permission when the table row is clicked', async () => {
      await createComponent({ mountFn: mountExtended });
      findTable().find('tbody tr').trigger('click');

      expectSelectedPermissions(['A']);
    });

    it('checks the permission when the checkbox is clicked', async () => {
      await createComponent({ mountFn: mountExtended });
      wrapper.findAllComponents(GlFormCheckbox).at(1).trigger('click');

      expectSelectedPermissions(['A']);
    });
  });

  describe('validation state', () => {
    it.each([true, false])('shows the expected text when isValid prop is %s', async (isValid) => {
      await createComponent({ mountFn: mountExtended, isValid });

      expect(wrapper.find('tbody td span').classes('gl-text-red-500')).toBe(!isValid);
    });
  });
});
