import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlSkeletonLoader,
  GlKeysetPagination,
  GlTable,
  GlFormCheckbox,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import CodeSuggestionsAddOnAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import {
  eligibleUsers,
  pageInfoWithNoPages,
  pageInfoWithMorePages,
  eligibleUsersWithMaxRole,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { ADD_ON_ERROR_DICTIONARY } from 'ee/usage_quotas/error_constants';
import { scrollToElement } from '~/lib/utils/common_utils';
import AddOnBulkActionConfirmationModal from 'ee/usage_quotas/code_suggestions/components/add_on_bulk_action_confirmation_modal.vue';

jest.mock('~/lib/utils/common_utils');

describe('Add On Eligible User List', () => {
  let wrapper;

  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';

  const createComponent = ({
    enableAddOnUsersFiltering = false,
    isBulkAddOnAssignmentEnabled = false,
    mountFn = shallowMount,
    props = {},
    slots = {},
  } = {}) => {
    wrapper = extendedWrapper(
      mountFn(AddOnEligibleUserList, {
        propsData: {
          addOnPurchaseId,
          users: eligibleUsers,
          pageInfo: pageInfoWithNoPages,
          isLoading: false,
          ...props,
        },
        provide: {
          glFeatures: {
            enableAddOnUsersFiltering,
          },
          isBulkAddOnAssignmentEnabled,
        },
        slots,
      }),
    );

    return waitForPromises();
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableKeys = () =>
    findTable()
      .props('fields')
      .map(({ key }) => key);
  const findAllCodeSuggestionsAddonComponents = () =>
    wrapper.findAllComponents(CodeSuggestionsAddOnAssignment);
  const findAddOnAssignmentError = () => wrapper.findByTestId('add-on-assignment-error');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const serializeUser = (rowWrapper) => {
    const avatarLink = rowWrapper.findComponent(GlAvatarLink);
    const avatarLabeled = rowWrapper.findComponent(GlAvatarLabeled);

    return {
      avatarLink: {
        href: avatarLink.attributes('href'),
        alt: avatarLink.attributes('alt'),
      },
      avatarLabeled: {
        src: avatarLabeled.attributes('src'),
        size: avatarLabeled.attributes('size'),
        text: avatarLabeled.text(),
      },
    };
  };

  const serializeTableRow = (rowWrapper) => {
    const emailWrapper = rowWrapper.find('[data-testid="email"]');
    const maxRoleWrapper = rowWrapper.find('[data-testid="max-role"]');

    return {
      user: serializeUser(rowWrapper),
      email: emailWrapper.text(),
      tooltip: emailWrapper.find('span').attributes('title'),
      lastActivityOn: rowWrapper.find('[data-testid="last-activity-on"]').text(),
      maxRole: maxRoleWrapper.exists() ? maxRoleWrapper.text() : undefined,
    };
  };

  const findSerializedTable = (tableWrapper) => {
    return tableWrapper.findAll('tbody tr').wrappers.map(serializeTableRow);
  };
  const findSelectAllUsersCheckbox = () => wrapper.findByTestId('select-all-users');
  const findSelectedUsersSummary = () => wrapper.findByTestId('selected-users-summary');
  const findSelectUserCheckboxAt = (index) =>
    wrapper.find('tbody').findAllComponents(GlFormCheckbox).at(index);
  const findAssignSeatsButton = () => wrapper.findByTestId('assign-seats-button');
  const findUnassignSeatsButton = () => wrapper.findByTestId('unassign-seats-button');
  const findConfirmationModal = () => wrapper.findComponent(AddOnBulkActionConfirmationModal);

  describe('renders table', () => {
    beforeEach(() => {
      return createComponent({
        mountFn: mount,
      });
    });

    it('renders the correct table data', () => {
      const expectedUserListData = [
        {
          email: 'Private',
          lastActivityOn: '2023-08-25',
          tooltip: 'An email address is only visible for users with public emails.',
          user: {
            avatarLabeled: { size: '32', src: 'path/to/img_userone', text: 'User One  @userone' },
            avatarLink: { alt: 'User One', href: 'path/to/userone' },
          },
        },
        {
          email: 'Private',
          lastActivityOn: '2023-08-22',
          tooltip: 'An email address is only visible for users with public emails.',
          user: {
            avatarLabeled: { size: '32', src: 'path/to/img_usertwo', text: 'User Two  @usertwo' },
            avatarLink: { alt: 'User Two', href: 'path/to/usertwo' },
          },
        },
        {
          email: 'Private',
          lastActivityOn: '2023-03-19',
          tooltip: 'An email address is only visible for users with public emails.',
          user: {
            avatarLabeled: {
              size: '32',
              src: 'path/to/img_userthree',
              text: 'User Three  @userthree',
            },
            avatarLink: { alt: 'User Three', href: 'path/to/userthree' },
          },
        },
      ];
      const actualUserListData = findSerializedTable(findTable());

      expect(actualUserListData).toEqual(expectedUserListData);
    });

    it('passes the correct fields configuration', () => {
      expect(findTableKeys()).toEqual([
        'user',
        'codeSuggestionsAddon',
        'email',
        'lastActivityTime',
      ]);
    });

    describe('with enableAddOnUsersFiltering enabled', () => {
      beforeEach(() => {
        return createComponent({ enableAddOnUsersFiltering: true });
      });

      it('passes the correct fields configuration', () => {
        expect(findTableKeys()).toEqual([
          'user',
          'codeSuggestionsAddon',
          'email',
          'lastActivityTime',
        ]);
      });

      describe('when eligible users have maxRole field', () => {
        beforeEach(() => {
          return createComponent({
            mountFn: mount,
            enableAddOnUsersFiltering: true,
            props: { users: eligibleUsersWithMaxRole },
          });
        });

        it('passes the correct fields configuration', () => {
          expect(findTableKeys()).toEqual([
            'user',
            'codeSuggestionsAddon',
            'email',
            'maxRole',
            'lastActivityTime',
          ]);
        });

        it('renders the correct table data', () => {
          const expectedUserListData = [
            {
              email: 'Private',
              lastActivityOn: '2023-08-25',
              maxRole: 'developer',
              tooltip: 'An email address is only visible for users with public emails.',
              user: {
                avatarLabeled: {
                  size: '32',
                  src: 'path/to/img_userone',
                  text: 'User One  @userone',
                },
                avatarLink: { alt: 'User One', href: 'path/to/userone' },
              },
            },
            {
              email: 'Private',
              lastActivityOn: '2023-08-22',
              maxRole: 'developer',
              tooltip: 'An email address is only visible for users with public emails.',
              user: {
                avatarLabeled: {
                  size: '32',
                  src: 'path/to/img_usertwo',
                  text: 'User Two  @usertwo',
                },
                avatarLink: { alt: 'User Two', href: 'path/to/usertwo' },
              },
            },
            {
              email: 'Private',
              lastActivityOn: '2023-03-19',
              maxRole: 'developer',
              tooltip: 'An email address is only visible for users with public emails.',
              user: {
                avatarLabeled: {
                  size: '32',
                  src: 'path/to/img_userthree',
                  text: 'User Three  @userthree',
                },
                avatarLink: { alt: 'User Three', href: 'path/to/userthree' },
              },
            },
          ];
          const actualUserListData = findSerializedTable(findTable());

          expect(actualUserListData).toStrictEqual(expectedUserListData);
        });
      });
    });

    describe('with isBulkAddOnAssignmentEnabled enabled', () => {
      beforeEach(() => {
        return createComponent({ isBulkAddOnAssignmentEnabled: true });
      });

      it('passes the correct fields configuration', () => {
        expect(findTableKeys()).toEqual([
          'checkbox',
          'user',
          'codeSuggestionsAddon',
          'email',
          'lastActivityTime',
        ]);
      });
    });

    describe('with enableAddOnUsersFiltering and isBulkAddOnAssignmentEnabled enabled', () => {
      beforeEach(() => {
        return createComponent({
          enableAddOnUsersFiltering: true,
          isBulkAddOnAssignmentEnabled: true,
        });
      });

      it('passes the correct fields configuration', () => {
        expect(findTableKeys()).toEqual([
          'checkbox',
          'user',
          'codeSuggestionsAddon',
          'email',
          'lastActivityTime',
        ]);
      });

      describe('when eligible users have maxRole field', () => {
        beforeEach(() => {
          return createComponent({
            mountFn: mount,
            enableAddOnUsersFiltering: true,
            isBulkAddOnAssignmentEnabled: true,
            props: { users: eligibleUsersWithMaxRole },
          });
        });

        it('passes the correct fields configuration', () => {
          expect(findTableKeys()).toEqual([
            'checkbox',
            'user',
            'codeSuggestionsAddon',
            'email',
            'maxRole',
            'lastActivityTime',
          ]);
        });
      });
    });

    describe('code suggestions addon', () => {
      describe('renders', () => {
        it('shows code suggestions addon field', () => {
          const expectedProps = [
            {
              userId: 'gid://gitlab/User/1',
              addOnAssignments: [{ addOnPurchase: { name: 'CODE_SUGGESTIONS' } }],
              addOnPurchaseId,
            },
            {
              userId: 'gid://gitlab/User/2',
              addOnAssignments: [],
              addOnPurchaseId,
            },
            {
              userId: 'gid://gitlab/User/3',
              addOnAssignments: [],
              addOnPurchaseId,
            },
          ];
          const actualProps = findAllCodeSuggestionsAddonComponents().wrappers.map((item) => ({
            userId: item.props('userId'),
            addOnAssignments: item.props('addOnAssignments'),
            addOnPurchaseId: item.props('addOnPurchaseId'),
          }));

          expect(actualProps).toMatchObject(expectedProps);
        });
      });

      describe('error slot', () => {
        it('should render error slot when provided', () => {
          const slotContent = 'error slot content';
          createComponent({
            mountFn: mount,
            slots: {
              'error-alert': slotContent,
            },
          });

          expect(wrapper.text()).toContain(slotContent);
        });
      });

      describe('search and sort bar slot', () => {
        it('should render error slot when provided', () => {
          const slotContent = 'search and sort bar content';
          createComponent({
            mountFn: mount,
            slots: {
              'search-and-sort-bar': slotContent,
            },
          });

          expect(wrapper.text()).toContain(slotContent);
        });
      });

      describe('when there is an error while assigning addon', () => {
        const addOnAssignmentError = 'NO_SEATS_AVAILABLE';
        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
          });
          findAllCodeSuggestionsAddonComponents()
            .at(0)
            .vm.$emit('handleAddOnAssignmentError', addOnAssignmentError);
        });

        it('shows an error alert', () => {
          const expectedProps = {
            dismissible: true,
            error: addOnAssignmentError,
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
          };
          expect(findAddOnAssignmentError().props()).toEqual(
            expect.objectContaining(expectedProps),
          );
        });

        it('clears error alert when dismissed', async () => {
          findAddOnAssignmentError().vm.$emit('dismiss');

          await nextTick();

          expect(findAddOnAssignmentError().exists()).toBe(false);
        });

        it('scrolls to the top of the table', () => {
          expect(scrollToElement).toHaveBeenCalled();
        });
      });
    });
  });

  describe('loading state', () => {
    describe('when not loading', () => {
      beforeEach(() => {
        return createComponent({
          mountFn: mount,
        });
      });

      it('displays the table in a non-busy state', () => {
        expect(findTable().attributes('busy')).toBe(undefined);
      });

      it('does not display the loading state', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
      });
    });

    describe('when loading', () => {
      beforeEach(() => {
        return createComponent({ props: { users: [], isLoading: true } });
      });

      it('displays the table in a busy state', () => {
        expect(findTable().attributes('busy')).toBe('true');
      });

      it('displays the loading state', () => {
        expect(findSkeletonLoader().exists()).toBe(true);
      });
    });
  });

  describe('pagination', () => {
    describe('when more pages exist', () => {
      beforeEach(() => {
        return createComponent({
          props: { pageInfo: pageInfoWithMorePages },
        });
      });

      it('pagination is rendered with correct values', () => {
        expect(findPagination().props()).toMatchObject({
          hasNextPage: true,
          hasPreviousPage: true,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
        });
      });

      it('triggers a call to addOnEligibleUsers with appropriate params on next', async () => {
        findPagination().vm.$emit('next');
        await waitForPromises();

        expect(wrapper.emitted('next')).toEqual([['end-cursor']]);
      });

      it('triggers a call to addOnEligibleUsers with appropriate params on prev', async () => {
        findPagination().vm.$emit('prev');
        await waitForPromises();

        expect(wrapper.emitted('prev')).toEqual([['start-cursor']]);
      });
    });

    describe('when only one page of results exists', () => {
      it('does not render pagination', async () => {
        await createComponent({
          mountFn: mount,
        });

        expect(findPagination().exists()).toBe(false);
      });
    });

    describe('when loading', () => {
      it('does not render pagination', () => {
        createComponent({ props: { users: [] } });

        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('search', () => {
    it('shows appropriate empty text when search term is insufficient', () => {
      const searchString = 'se';

      createComponent({ props: { search: searchString } });

      expect(findTable().attributes()).toMatchObject({
        'empty-text': 'Enter at least three characters to search.',
        'show-empty': 'true',
      });
    });

    it('triggers a call to addOnEligibleUsers with appropriate params on filter', () => {
      const searchString = 'search string';

      createComponent({ props: { search: searchString } });

      expect(findTable().attributes('empty-text')).toBe('No users to display.');
    });
  });

  describe('user cell slot', () => {
    it('correctly displays the content', () => {
      createComponent({
        slots: {
          'user-cell': '<div class="user-cell">A user cell content</div>',
        },
      });

      expect(wrapper.find('.user-cell').text()).toBe('A user cell content');
    });
  });

  describe('bulk assignment', () => {
    describe('when using select all option', () => {
      beforeEach(async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        findSelectAllUsersCheckbox().find('input').setChecked(true);
        await nextTick();
      });

      it('shows a summary of all users selected when select all users checkbox is clicked', () => {
        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText(
          `${eligibleUsers.length} users selected`,
        );
      });

      it('does not show a summary of users when unselect all users checkbox is clicked', async () => {
        findSelectAllUsersCheckbox().find('input').setChecked(false);
        await nextTick();

        expect(findSelectedUsersSummary().exists()).toBe(false);
      });

      it('shows confirmation modal when assign seats CTA is clicked', async () => {
        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'ASSIGN_BULK_ACTION',
          userCount: eligibleUsers.length,
        });
      });

      it('shows confirmation modal when unassign seats CTA is clicked', async () => {
        findUnassignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'UNASSIGN_BULK_ACTION',
          userCount: eligibleUsers.length,
        });
      });
    });

    describe('when using individual checkboxes', () => {
      beforeEach(async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        findSelectUserCheckboxAt(1).find('input').setChecked(true);
        findSelectUserCheckboxAt(2).find('input').setChecked(true);
        await nextTick();
      });

      it('shows a summary of only the selected users', () => {
        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('2 users selected');
      });

      it('pluralises user count appropriately', async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        findSelectUserCheckboxAt(1).find('input').setChecked(true);
        await nextTick();

        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('1 user selected');
      });

      it('shows confirmation modal when assign seats CTA is clicked', async () => {
        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'ASSIGN_BULK_ACTION',
          userCount: 2,
        });
      });

      it('shows confirmation modal when unassign seats CTA is clicked', async () => {
        findUnassignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'UNASSIGN_BULK_ACTION',
          userCount: 2,
        });
      });
    });

    describe('confirmation modal', () => {
      beforeEach(async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });
      });

      it('does not show confirmation modal when no users are selected', () => {
        expect(findConfirmationModal().exists()).toBe(false);
      });

      it('hides the confirmation modal when cancelled', async () => {
        findSelectAllUsersCheckbox().find('input').setChecked(true);
        await nextTick();

        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        findConfirmationModal().vm.$emit('cancel');
        await nextTick();

        expect(findConfirmationModal().exists()).toBe(false);
      });
    });

    describe('when paginating', () => {
      beforeEach(async () => {
        createComponent({
          mountFn: mount,
          isBulkAddOnAssignmentEnabled: true,
          props: { pageInfo: pageInfoWithMorePages },
        });

        findSelectAllUsersCheckbox().find('input').setChecked(true);
        await nextTick();
      });

      it('resets user selection on navigating to next page', async () => {
        findPagination().vm.$emit('next');
        await waitForPromises();

        expect(findSelectedUsersSummary().exists()).toBe(false);
      });

      it('resets user selection on navigating to previous page', async () => {
        findPagination().vm.$emit('prev');
        await waitForPromises();

        expect(findSelectedUsersSummary().exists()).toBe(false);
      });
    });
  });
});
