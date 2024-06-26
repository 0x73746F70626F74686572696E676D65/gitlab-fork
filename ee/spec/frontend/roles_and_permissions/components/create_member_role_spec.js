import { GlFormInput, GlFormSelect, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import createMemberRoleMutation from 'ee/roles_and_permissions/graphql/create_member_role.mutation.graphql';
import updateMemberRoleMutation from 'ee/roles_and_permissions/graphql/update_member_role.mutation.graphql';
import CreateMemberRole from 'ee/roles_and_permissions/components/create_member_role.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import memberRoleQuery from 'ee/roles_and_permissions/graphql/member_role.query.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import PermissionsSelector from 'ee/roles_and_permissions/components/permissions_selector.vue';
import { mockMemberRoleQueryResponse } from '../mock_data';

Vue.use(VueApollo);

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

const mutationSuccessData = { data: { memberRoleSave: { errors: [] } } };

describe('CreateMemberRole', () => {
  let wrapper;

  const createMutationSuccessHandler = jest.fn().mockResolvedValue(mutationSuccessData);
  const updateMutationSuccessHandler = jest.fn().mockResolvedValue(mutationSuccessData);
  const defaultMemberRoleHandler = jest.fn().mockResolvedValue(mockMemberRoleQueryResponse);

  const createComponent = ({
    stubs,
    createMutationMock = createMutationSuccessHandler,
    updateMutationMock = updateMutationSuccessHandler,
    memberRoleHandler = defaultMemberRoleHandler,
    groupFullPath = 'test-group',
    embedded = false,
    roleId,
  } = {}) => {
    wrapper = mountExtended(CreateMemberRole, {
      propsData: { groupFullPath, embedded, listPagePath: 'http://list/page/path', roleId },
      stubs: { PermissionsSelector: true, ...stubs },
      apolloProvider: createMockApollo([
        [memberRoleQuery, memberRoleHandler],
        [createMemberRoleMutation, createMutationMock],
        [updateMemberRoleMutation, updateMutationMock],
      ]),
    });

    return waitForPromises();
  };

  const findButtonSubmit = () => wrapper.findByTestId('submit-button');
  const findButtonCancel = () => wrapper.findByTestId('cancel-button');
  const findNameField = () => wrapper.findAllComponents(GlFormInput).at(0);
  const findSelect = () => wrapper.findComponent(GlFormSelect);
  const findDescriptionField = () => wrapper.findAllComponents(GlFormInput).at(1);
  const findPermissionsSelector = () => wrapper.findComponent(PermissionsSelector);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const fillForm = () => {
    findSelect().setValue('GUEST');
    findNameField().setValue('My role name');
    findDescriptionField().setValue('My description');
    findPermissionsSelector().vm.$emit('change', ['A']);

    return nextTick();
  };

  const submitForm = (waitFn = nextTick) => {
    findButtonSubmit().trigger('submit');
    return waitFn();
  };

  it('shows the role dropdown with the expected options', () => {
    // GlFormSelect doesn't stub the options prop properly, create a stub that does it properly.
    const stubs = { GlFormSelect: stubComponent(GlFormSelect, { props: ['options'] }) };
    createComponent({ stubs });

    expect(findSelect().props('options')).toEqual([
      { value: 'MINIMAL_ACCESS', text: 'Minimal Access' },
      { value: 'GUEST', text: 'Guest' },
      { value: 'REPORTER', text: 'Reporter' },
      { value: 'DEVELOPER', text: 'Developer' },
      { value: 'MAINTAINER', text: 'Maintainer' },
      { value: 'OWNER', text: 'Owner' },
    ]);
  });

  it('navigates back to list page when cancel button is clicked', () => {
    createComponent();

    findButtonCancel().trigger('click');

    expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
  });

  it('does not fetch a member role on page load when creating a role', () => {
    createComponent();

    expect(defaultMemberRoleHandler).not.toHaveBeenCalled();
  });

  describe('embedded mode', () => {
    it('emits cancel event when the cancel button is clicked', () => {
      createComponent({ embedded: true });

      expect(wrapper.emitted('cancel')).toBeUndefined();

      findButtonCancel().trigger('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('field validation', () => {
    beforeEach(createComponent);

    it('shows a warning if no base role is selected', async () => {
      expect(findSelect().classes()).not.toContain('is-invalid');

      await submitForm();

      expect(findSelect().classes()).toContain('is-invalid');
    });

    it('shows a warning if name field is empty', async () => {
      expect(findNameField().classes()).toContain('is-valid');

      await submitForm();

      expect(findNameField().classes()).toContain('is-invalid');
    });

    it('shows a warning if no permissions are selected', async () => {
      expect(findPermissionsSelector().props('isValid')).toBe(true);

      findPermissionsSelector().vm.$emit('update:permissions', []);
      await submitForm();

      expect(findPermissionsSelector().props('isValid')).toBe(false);
    });
  });

  describe('when create role form is submitted', () => {
    it('disables the submit and cancel buttons', async () => {
      await createComponent();
      await fillForm();
      // Verify that the buttons don't start off as disabled.
      expect(findButtonSubmit().props('loading')).toBe(false);
      expect(findButtonCancel().props('disabled')).toBe(false);

      await submitForm();

      expect(findButtonSubmit().props('loading')).toBe(true);
      expect(findButtonCancel().props('disabled')).toBe(true);
    });

    it('dismisses any previous alert', async () => {
      await createComponent({ createMutationMock: jest.fn().mockRejectedValue() });
      await fillForm();
      await submitForm(waitForPromises);

      // Verify that the first alert was created and not dismissed.
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(0);

      await submitForm(waitForPromises);

      // Verify that the second alert was created and the first was dismissed.
      expect(createAlert).toHaveBeenCalledTimes(2);
      expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
    });

    it.each(['group-path', null])(
      'calls the mutation with the correct data when groupFullPath is %s',
      async (groupFullPath) => {
        await createComponent({ groupFullPath });
        await fillForm();
        await submitForm();

        const input = {
          baseAccessLevel: 'GUEST',
          name: 'My role name',
          description: 'My description',
          permissions: ['A'],
          ...(groupFullPath ? { groupPath: groupFullPath } : {}),
        };

        expect(createMutationSuccessHandler).toHaveBeenCalledWith({ input });
      },
    );
  });

  describe('when create role succeeds', () => {
    it('redirects to the list page path', async () => {
      await createComponent();
      await fillForm();
      await submitForm(waitForPromises);

      expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
    });

    describe('embedded mode', () => {
      it('emits success event', async () => {
        await createComponent({ embedded: true });
        await fillForm();

        expect(wrapper.emitted('success')).toBeUndefined();

        await submitForm(waitForPromises);

        expect(wrapper.emitted('success')).toHaveLength(1);
      });
    });
  });

  describe('when there is an error creating the role', () => {
    const createMutationMock = jest
      .fn()
      .mockResolvedValue({ data: { memberRoleSave: { errors: ['reason'] } } });

    beforeEach(async () => {
      await createComponent({ createMutationMock });
      await fillForm();
    });

    it('shows an error alert', async () => {
      await submitForm(waitForPromises);

      expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to create role: reason' });
    });

    it('enables the submit and cancel buttons', () => {
      expect(findButtonSubmit().props('loading')).toBe(false);
      expect(findButtonCancel().props('disabled')).toBe(false);
    });

    it('does not emit the success event', () => {
      expect(wrapper.emitted('success')).toBeUndefined();
    });
  });

  describe('edit role', () => {
    describe('on page load', () => {
      beforeEach(() => {
        createComponent({ roleId: 1 });
      });

      it('shows a loading spinner', () => {
        createComponent({ roleId: 1 });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('starts the member role query', () => {
        expect(defaultMemberRoleHandler).toHaveBeenCalledTimes(1);
        expect(defaultMemberRoleHandler).toHaveBeenCalledWith({ id: 'gid://gitlab/MemberRole/1' });
      });
    });

    describe('on role fetch error', () => {
      it('shows error message when there is no role', async () => {
        const memberRoleHandler = jest.fn().mockResolvedValue({ data: { memberRole: null } });
        await createComponent({ roleId: 1, memberRoleHandler });

        expect(findAlert().text()).toBe('Failed to load custom role.');
      });

      it('shows error message when there was an error fetching the role', async () => {
        const memberRoleHandler = jest.fn().mockRejectedValue();
        await createComponent({ roleId: 1, memberRoleHandler });

        expect(findAlert().text()).toBe('Failed to load custom role.');
      });
    });

    describe('after the member role is loaded', () => {
      beforeEach(() => {
        return createComponent({ roleId: 1, stubs: { GlFormCheckboxGroup: true } });
      });

      it('shows the form with the expected pre-filled data', () => {
        expect(findSelect().element.value).toBe('DEVELOPER');
        expect(findNameField().element.value).toBe('Custom role');
        expect(findDescriptionField().element.value).toBe('Custom role description');
        expect(findPermissionsSelector().props('permissions')).toEqual(['A', 'B']);
      });

      it('disables the base role selector', () => {
        expect(findSelect().element.disabled).toBe(true);
      });
    });

    describe('saving the role', () => {
      it('calls the update mutation with the expected data', async () => {
        await createComponent({ roleId: 1 });
        await submitForm();

        expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            id: 'gid://gitlab/MemberRole/1',
            name: 'Custom role',
            description: 'Custom role description',
            permissions: ['A', 'B'],
          },
        });
      });
    });
  });
});
