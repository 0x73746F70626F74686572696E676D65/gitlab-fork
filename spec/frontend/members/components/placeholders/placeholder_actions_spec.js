import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import PlaceholderActions from '~/members/components/placeholders/placeholder_actions.vue';
import searchUsersQuery from '~/graphql_shared/queries/users_search_all_paginated.query.graphql';
import importSourceUserReassignMutation from '~/members/placeholders/graphql/mutations/reassign.mutation.graphql';
import importSourceUserKeepAsPlaceholderMutation from '~/members/placeholders/graphql/mutations/keep_as_placeholder.mutation.graphql';
import importSourceUserCancelReassignmentMutation from '~/members/placeholders/graphql/mutations/cancel_reassignment.mutation.graphql';

import {
  mockSourceUsers,
  mockReassignMutationResponse,
  mockKeepAsPlaceholderMutationResponse,
  mockCancelReassignmentMutationResponse,
  mockUser1,
  mockUser2,
  mockUsersQueryResponse,
  mockUsersWithPaginationQueryResponse,
} from './mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('PlaceholderActions', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    sourceUser: mockSourceUsers[0],
  };
  const usersQueryHandler = jest.fn().mockResolvedValue(mockUsersQueryResponse);
  const reassignMutationHandler = jest.fn().mockResolvedValue(mockReassignMutationResponse);
  const keepAsPlaceholderMutationHandler = jest
    .fn()
    .mockResolvedValue(mockKeepAsPlaceholderMutationResponse);
  const cancelReassignmentMutationHandler = jest
    .fn()
    .mockResolvedValue(mockCancelReassignmentMutationResponse);
  const $toast = {
    show: jest.fn(),
  };

  const createComponent = ({ seachUsersQueryHandler = usersQueryHandler, props = {} } = {}) => {
    mockApollo = createMockApollo([
      [searchUsersQuery, seachUsersQueryHandler],
      [importSourceUserReassignMutation, reassignMutationHandler],
      [importSourceUserKeepAsPlaceholderMutation, keepAsPlaceholderMutationHandler],
      [importSourceUserCancelReassignmentMutation, cancelReassignmentMutationHandler],
    ]);

    wrapper = shallowMountExtended(PlaceholderActions, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: { $toast },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDontReassignButton = () => wrapper.findByTestId('dont-reassign-button');
  const findNotifyButton = () => wrapper.findByTestId('notify-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findConfirmButton = () => wrapper.findByTestId('confirm-button');

  it('renders listbox with infinite scroll', () => {
    createComponent();

    expect(findListbox().props()).toMatchObject({
      toggleText: 'Select user',
      infiniteScroll: true,
    });
  });

  describe('when users query is loading', () => {
    it('renders listbox as loading', () => {
      createComponent();

      expect(findListbox().props('loading')).toBe(true);
    });
  });

  describe('when users query fails', () => {
    beforeEach(async () => {
      const usersFailedQueryHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

      createComponent({
        seachUsersQueryHandler: usersFailedQueryHandler,
      });
      await waitForPromises();
    });

    it('creates an alert', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: 'There was a problem fetching users.' });
    });
  });

  describe('when users query succeeds', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    describe('when nothing is selected', () => {
      it('does not render validation message initially', () => {
        expect(wrapper.findByText('This field is required.').exists()).toBe(false);
      });

      it('renders validation message when Confirm button is clicked', async () => {
        findConfirmButton().vm.$emit('click');
        await nextTick();

        expect(wrapper.findByText('This field is required.').exists()).toBe(true);
      });
    });

    describe('when "Don\'t reassign" is selected', () => {
      beforeEach(() => {
        findDontReassignButton().vm.$emit('click');
      });

      it('renders listbox with "Don\'t reassign" toggle text', () => {
        expect(findListbox().props('toggleText')).toBe("Don't reassign");
      });

      it('renders confirm button as "Confirm"', () => {
        expect(findConfirmButton().text()).toBe('Confirm');
        expect(findConfirmButton().props()).toMatchObject({
          disabled: false,
          loading: false,
        });
      });

      describe('when Confirm button is clicked', () => {
        beforeEach(async () => {
          findConfirmButton().vm.$emit('click');
          await nextTick();
        });

        it('calls keepAsPlaceholder mutation', async () => {
          expect(findConfirmButton().props('loading')).toBe(true);
          await waitForPromises();
          expect(findConfirmButton().props('loading')).toBe(false);

          expect(keepAsPlaceholderMutationHandler).toHaveBeenCalledWith({
            id: mockSourceUsers[0].id,
          });
        });
      });
    });

    describe('when user is selected', () => {
      beforeEach(() => {
        findListbox().vm.$emit('select', mockUser1.id);
      });

      it('renders listbox with @username as toggle text', () => {
        expect(findListbox().props('toggleText')).toBe(`@${mockUser1.username}`);
      });

      it('renders confirm button as "Reassign"', () => {
        expect(findConfirmButton().text()).toBe('Reassign');
        expect(findConfirmButton().props()).toMatchObject({
          disabled: false,
          loading: false,
        });
      });

      describe('when Reassign button is clicked', () => {
        beforeEach(async () => {
          findConfirmButton().vm.$emit('click');
          await nextTick();
        });

        it('calls reassign mutation', async () => {
          expect(findConfirmButton().props('loading')).toBe(true);
          await waitForPromises();
          expect(findConfirmButton().props('loading')).toBe(false);

          expect(reassignMutationHandler).toHaveBeenCalledWith({
            id: mockSourceUsers[0].id,
            userId: mockUser1.id,
          });
        });
      });
    });
  });

  describe('when users query succeeds and has pagination', () => {
    const usersPaginatedQueryHandler = jest.fn();

    beforeEach(async () => {
      usersPaginatedQueryHandler
        .mockResolvedValueOnce(mockUsersWithPaginationQueryResponse)
        .mockResolvedValueOnce(mockUsersQueryResponse);

      createComponent({
        seachUsersQueryHandler: usersPaginatedQueryHandler,
      });
      await waitForPromises();
    });

    describe('when "bottom-reached" event is emitted', () => {
      beforeEach(() => {
        findListbox().vm.$emit('bottom-reached');
      });

      it('calls fetchMore to get next page', () => {
        expect(findListbox().props('infiniteScrollLoading')).toBe(true);

        expect(usersPaginatedQueryHandler).toHaveBeenCalledTimes(2);
        expect(usersPaginatedQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: 'end123',
          }),
        );
      });

      it('appends query results to "items"', async () => {
        const allUsers = [mockUser2, mockUser1];

        await waitForPromises();

        expect(findListbox().props('infiniteScrollLoading')).toBe(false);

        const dropdownItems = findListbox().props('items');
        expect(dropdownItems).toHaveLength(allUsers.length);
        dropdownItems.forEach((user, index) => {
          expect(user).toMatchObject({
            id: allUsers[index].id,
            name: allUsers[index].name,
            value: allUsers[index].id,
          });
        });
      });
    });
  });

  describe('when status is PENDING_ASSIGNMENT', () => {
    beforeEach(() => {
      createComponent({
        props: {
          sourceUser: { status: 'PENDING_ASSIGNMENT' },
        },
      });
    });

    it('does not render Notify button', () => {
      expect(findNotifyButton().exists()).toBe(false);
    });

    it('does not render Cancel button', () => {
      expect(findCancelButton().exists()).toBe(false);
    });

    it('renders Confirm button', () => {
      expect(findConfirmButton().exists()).toBe(true);
    });
  });

  describe('when status is AWAITING_APPROVAL', () => {
    const mockSourceUser = mockSourceUsers[1];

    beforeEach(() => {
      createComponent({
        props: {
          sourceUser: {
            ...mockSourceUser,
            status: 'AWAITING_APPROVAL',
          },
        },
      });
    });

    it('renders disabled listbox with @username toggle text', () => {
      expect(findListbox().props()).toMatchObject({
        toggleText: `@${mockSourceUser.reassignToUser.username}`,
        disabled: true,
      });
    });

    it('renders Notify button', () => {
      expect(findCancelButton().props('disabled')).toBe(false);
    });

    it('renders Cancel button', () => {
      expect(findCancelButton().props('disabled')).toBe(false);
    });

    it('does not render Confirm button', () => {
      expect(findConfirmButton().exists()).toBe(false);
    });

    it('shows toast when Notify button is clicked', () => {
      findNotifyButton().vm.$emit('click');

      expect($toast.show).toHaveBeenCalledWith('Notification email sent.');
    });

    describe('when Cancel button is clicked', () => {
      beforeEach(async () => {
        findCancelButton().vm.$emit('click');
        await nextTick();
      });

      it('calls cancelReassignment mutation', async () => {
        expect(findCancelButton().props('loading')).toBe(true);
        await waitForPromises();
        expect(findCancelButton().props('loading')).toBe(false);

        expect(cancelReassignmentMutationHandler).toHaveBeenCalledWith({
          id: mockSourceUser.id,
        });
      });
    });
  });

  describe('when status is REASSIGNMENT_IN_PROGRESS', () => {
    const mockSourceUser = mockSourceUsers[3];

    beforeEach(() => {
      createComponent({
        props: {
          sourceUser: {
            ...mockSourceUser,
            status: 'REASSIGNMENT_IN_PROGRESS',
          },
        },
      });
    });

    it('renders disabled listbox with @username toggle text', () => {
      expect(findListbox().props()).toMatchObject({
        toggleText: `@${mockSourceUser.reassignToUser.username}`,
        disabled: true,
      });
    });

    it('renders disabled Notify button', () => {
      expect(findCancelButton().props('disabled')).toBe(true);
    });

    it('renders disabled Cancel button', () => {
      expect(findCancelButton().props('disabled')).toBe(true);
    });

    it('does not render Confirm button', () => {
      expect(findConfirmButton().exists()).toBe(false);
    });
  });
});
