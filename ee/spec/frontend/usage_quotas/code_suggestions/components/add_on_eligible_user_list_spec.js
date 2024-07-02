import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlSkeletonLoader,
  GlKeysetPagination,
  GlTable,
  GlFormCheckbox,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import CodeSuggestionsAddOnAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import {
  eligibleUsers,
  pageInfoWithNoPages,
  pageInfoWithMorePages,
  eligibleUsersWithMaxRole,
  mockAddOnEligibleUsers,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import { scrollToElement } from '~/lib/utils/common_utils';
import AddOnBulkActionConfirmationModal from 'ee/usage_quotas/code_suggestions/components/add_on_bulk_action_confirmation_modal.vue';
import {
  ADD_ON_CODE_SUGGESTIONS,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import userAddOnAssignmentBulkCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_create.mutation.graphql';
import userAddOnAssignmentBulkRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_remove.mutation.graphql';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';

Vue.use(VueApollo);

jest.mock('~/lib/utils/common_utils');
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils', () => ({
  convertObjectPropsToLowerCase: jest.requireActual('~/lib/utils/common_utils')
    .convertObjectPropsToLowerCase,
  scrollToElement: jest.fn(),
}));

describe('Add On Eligible User List', () => {
  let wrapper;

  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const addDuoProHref = 'http://customers.gitlab.com/namespaces/0/duo_pro_seats';

  const codeSuggestionsAddOn = { addOnPurchase: { name: ADD_ON_CODE_SUGGESTIONS } };

  const addOnPurchase = {
    id: addOnPurchaseId,
    name: ADD_ON_CODE_SUGGESTIONS,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };

  const addOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: 'CODE_SUGGESTIONS',
    addOnPurchaseIds: [addOnPurchaseId],
  };

  const bulkAddOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase,
    users: {
      nodes: [
        {
          id: eligibleUsers[1].id,
          addOnAssignments: {
            nodes: codeSuggestionsAddOn,
            __typename: 'UserAddOnAssignmentConnection',
          },
          __typename: 'AddOnUser',
        },
        {
          id: eligibleUsers[2].id,
          addOnAssignments: {
            nodes: codeSuggestionsAddOn,
            __typename: 'UserAddOnAssignmentConnection',
          },
          __typename: 'AddOnUser',
        },
      ],
    },
  };

  const bulkAddOnUnassignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase,
    users: {
      nodes: [
        {
          id: eligibleUsers[0].id,
          addOnAssignments: {
            nodes: [],
            __typename: 'UserAddOnAssignmentConnection',
          },
          __typename: 'AddOnUser',
        },
        {
          id: eligibleUsers[1].id,
          addOnAssignments: {
            nodes: [],
            __typename: 'UserAddOnAssignmentConnection',
          },
          __typename: 'AddOnUser',
        },
      ],
    },
  };

  const knownAddOnBulkAssignmentError = {
    clientMutationId: '1',
    errors: ['NOT_ENOUGH_SEATS'],
    addOnPurchase: null,
    users: null,
  };

  const noAssignmentsFoundError = {
    clientMutationId: '1',
    errors: ['NO_ASSIGNMENTS_FOUND'],
    addOnPurchase: null,
    users: null,
  };

  const unknownErrorCodeError = {
    clientMutationId: '1',
    errors: ['UNKNOWN_ERROR_CODE'],
    addOnPurchase: null,
    users: null,
  };

  const bulkAssignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentBulkCreate: bulkAddOnAssignmentSuccess },
  });

  const bulkUnassignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentBulkRemove: bulkAddOnUnassignmentSuccess },
  });

  let mockHandlerGetSubscriptionPermissionData = jest.fn().mockResolvedValue({
    data: {
      subscription: {
        canAddSeats: false,
        canRenew: false,
        communityPlan: false,
        canAddDuoProSeats: true,
      },
      userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
    },
  });

  const createMockApolloProvider = (
    addonAssignmentBulkCreateHandler,
    addonAssignmentBulkRemoveHandler,
  ) => {
    const mockClient = createMockClient([
      [userAddOnAssignmentBulkCreateMutation, addonAssignmentBulkCreateHandler],
      [userAddOnAssignmentBulkRemoveMutation, addonAssignmentBulkRemoveHandler],
    ]);
    const mockClientCustomersDot = createMockClient([
      [getSubscriptionPermissionsData, mockHandlerGetSubscriptionPermissionData],
    ]);
    const mockApollo = new VueApollo({
      defaultClient: mockClient,
      clients: { customersDotClient: mockClientCustomersDot },
    });

    // Needed to check if cache update is successful on successful mutation
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getAddOnEligibleUsers,
      variables: addOnEligibleUsersQueryVariables,
      data: mockAddOnEligibleUsers.data,
    });

    return mockApollo;
  };

  let mockApolloClient;

  const createComponent = ({
    enableAddOnUsersFiltering = false,
    isBulkAddOnAssignmentEnabled = false,
    addonAssignmentBulkCreateHandler = bulkAssignAddOnHandler,
    addonAssignmentBulkRemoveHandler = bulkUnassignAddOnHandler,
    mountFn = shallowMount,
    props = {},
    slots = {},
  } = {}) => {
    mockApolloClient = createMockApolloProvider(
      addonAssignmentBulkCreateHandler,
      addonAssignmentBulkRemoveHandler,
    );

    wrapper = extendedWrapper(
      mountFn(AddOnEligibleUserList, {
        apolloProvider: mockApolloClient,
        propsData: {
          addOnPurchaseId,
          users: eligibleUsers,
          pageInfo: pageInfoWithNoPages,
          isLoading: false,
          duoTier: 'pro',
          ...props,
        },
        provide: {
          addDuoProHref,
          glFeatures: {
            enableAddOnUsersFiltering,
          },
          isBulkAddOnAssignmentEnabled,
          groupId: 1,
          subscriptionName: null,
        },
        slots,
      }),
    );

    return waitForPromises();
  };

  const getAddOnAssignmentStatusForUserFromCache = (userId) => {
    return mockApolloClient.clients.defaultClient.cache
      .readQuery({ query: getAddOnEligibleUsers, variables: addOnEligibleUsersQueryVariables })
      .namespace.addOnEligibleUsers.nodes.find((node) => node.id === userId).addOnAssignments.nodes;
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableKeys = () =>
    findTable()
      .props('fields')
      .map(({ key }) => key);
  const findTableLabels = () =>
    findTable()
      .props('fields')
      .map(({ label }) => label);
  const findAllCodeSuggestionsAddonComponents = () =>
    wrapper.findAllComponents(CodeSuggestionsAddOnAssignment);
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
  const findSuccessAlert = () => wrapper.findByTestId('success-alert');
  const findErrorAlert = () => wrapper.findByTestId('error-alert');

  const confirmSeatAssignment = async () => {
    await findSelectUserCheckboxAt(1).find('input').setChecked(true);
    await findSelectUserCheckboxAt(2).find('input').setChecked(true);

    findAssignSeatsButton().vm.$emit('click');
    await nextTick();

    findConfirmationModal().vm.$emit('confirm-seat-assignment');
    await nextTick();
  };

  const confirmSeatUnassignment = async () => {
    await findSelectUserCheckboxAt(0).find('input').setChecked(true);
    await findSelectUserCheckboxAt(1).find('input').setChecked(true);

    findUnassignSeatsButton().vm.$emit('click');
    await nextTick();

    findConfirmationModal().vm.$emit('confirm-seat-unassignment');
    await nextTick();
  };

  const triggerErrorAlertNoSeatsAvailable = async () => {
    await createComponent({
      mountFn: mount,
    });
    findAllCodeSuggestionsAddonComponents().at(0).vm.$emit('handleError', 'NO_SEATS_AVAILABLE');
    await nextTick();
  };

  const triggerErrorAlertNotEnoughSeats = async () => {
    await createComponent({
      mountFn: mount,
      isBulkAddOnAssignmentEnabled: true,
      addonAssignmentBulkCreateHandler: jest.fn().mockResolvedValue({
        data: { userAddOnAssignmentBulkCreate: knownAddOnBulkAssignmentError },
      }),
    });
    await confirmSeatAssignment();
    await waitForPromises();
  };

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

    it('labels add-on column as Duo Pro', () => {
      expect(findTableLabels()).toContain(CODE_SUGGESTIONS_TITLE);
    });

    describe('with Duo Enterprise add-on enabled', () => {
      beforeEach(() => {
        return createComponent({
          mountFn: mount,
          props: { duoTier: DUO_ENTERPRISE },
        });
      });

      it('labels add-on column as Duo Enterprise', () => {
        expect(findTableLabels()).toContain(DUO_ENTERPRISE_TITLE);
      });
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
        const error = 'NO_SEATS_AVAILABLE';

        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
          });
          findAllCodeSuggestionsAddonComponents().at(0).vm.$emit('handleError', error);
        });

        it('shows an error alert', () => {
          const expectedProps = {
            dismissible: true,
            error,
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
          };
          expect(findErrorAlert().props()).toEqual(expect.objectContaining(expectedProps));
        });

        it('clears error alert when dismissed', async () => {
          findErrorAlert().vm.$emit('dismiss');

          await nextTick();

          expect(findErrorAlert().exists()).toBe(false);
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

  describe('bulk action', () => {
    describe('when using select all option', () => {
      beforeEach(async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        await findSelectAllUsersCheckbox().find('input').setChecked(true);
      });

      it('shows a summary of all users selected when select all users checkbox is clicked', () => {
        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText(
          `${eligibleUsers.length} users selected`,
        );
      });

      it('does not show a summary of users when unselect all users checkbox is clicked', async () => {
        await findSelectAllUsersCheckbox().find('input').setChecked(false);

        expect(findSelectedUsersSummary().exists()).toBe(false);
      });

      it('shows confirmation modal when assign seats CTA is clicked', async () => {
        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'ASSIGN_BULK_ACTION',
          isBulkActionInProgress: false,
          userCount: eligibleUsers.length,
        });
      });

      it('shows confirmation modal when unassign seats CTA is clicked', async () => {
        findUnassignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'UNASSIGN_BULK_ACTION',
          isBulkActionInProgress: false,
          userCount: eligibleUsers.length,
        });
      });
    });

    describe('when using individual checkboxes', () => {
      beforeEach(async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        await findSelectUserCheckboxAt(1).find('input').setChecked(true);
        await findSelectUserCheckboxAt(2).find('input').setChecked(true);
      });

      it('shows a summary of only the selected users', () => {
        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('2 users selected');
      });

      it('pluralises user count appropriately', async () => {
        await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

        await findSelectUserCheckboxAt(1).find('input').setChecked(true);

        expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('1 user selected');
      });

      it('shows confirmation modal when assign seats CTA is clicked', async () => {
        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'ASSIGN_BULK_ACTION',
          isBulkActionInProgress: false,
          userCount: 2,
        });
      });

      it('shows confirmation modal when unassign seats CTA is clicked', async () => {
        findUnassignSeatsButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmationModal().props()).toEqual({
          bulkAction: 'UNASSIGN_BULK_ACTION',
          isBulkActionInProgress: false,
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
        await findSelectAllUsersCheckbox().find('input').setChecked(true);

        findAssignSeatsButton().vm.$emit('click');
        await nextTick();

        findConfirmationModal().vm.$emit('cancel');
        await nextTick();

        expect(findConfirmationModal().exists()).toBe(false);
      });
    });

    describe('bulk assignment confirmation', () => {
      describe('successful assignment', () => {
        beforeEach(async () => {
          await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

          await confirmSeatAssignment();
        });

        it('calls bulk addon assignment mutation with appropriate params', () => {
          expect(bulkAssignAddOnHandler).toHaveBeenCalledWith({
            addOnPurchaseId,
            userIds: [eligibleUsers[1].id, eligibleUsers[2].id],
          });
        });

        it('shows a loading state', () => {
          expect(findConfirmationModal().props().isBulkActionInProgress).toBe(true);
        });

        it('updates the cache with latest add-on assignment status', async () => {
          await waitForPromises();

          expect(getAddOnAssignmentStatusForUserFromCache(eligibleUsers[1].id)).toEqual(
            codeSuggestionsAddOn,
          );
          expect(getAddOnAssignmentStatusForUserFromCache(eligibleUsers[2].id)).toEqual(
            codeSuggestionsAddOn,
          );
        });

        it('does not show the confirmation modal on successful API call', async () => {
          await waitForPromises();

          expect(findConfirmationModal().exists()).toBe(false);
        });

        it('unselects users on successful API call', async () => {
          expect(findSelectedUsersSummary().exists()).toBe(true);

          await waitForPromises();

          expect(findSelectedUsersSummary().exists()).toBe(false);
        });

        it('shows a success alert', async () => {
          await waitForPromises();

          expect(findSuccessAlert().text()).toBe('2 users have been successfully assigned a seat.');
        });
      });

      describe('unsuccessful assignment', () => {
        const error = new Error('An error');

        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
            isBulkAddOnAssignmentEnabled: true,
            addonAssignmentBulkCreateHandler: jest.fn().mockRejectedValue(error),
          });

          await confirmSeatAssignment();
        });

        it('captures error on Sentry for generic errors', async () => {
          await waitForPromises();

          expect(Sentry.captureException).toHaveBeenCalledWith(error);
        });

        it('does not show the confirmation modal on unsuccessful API call', async () => {
          await waitForPromises();

          expect(findConfirmationModal().exists()).toBe(false);
        });

        it('retains user selection on unsuccessful API call', async () => {
          await waitForPromises();

          expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('2 users selected');
        });

        it('shows a generic error alert', async () => {
          await waitForPromises();

          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'CANNOT_BULK_ASSIGN_ADDON',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
          });
        });

        it('shows no add seats button', async () => {
          await waitForPromises();

          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'CANNOT_BULK_ASSIGN_ADDON',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
            primaryButtonLink: addDuoProHref,
            primaryButtonText: '',
            secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
            secondaryButtonText: 'Contact sales',
          });
        });

        it('scrolls to the top of the table', () => {
          expect(scrollToElement).toHaveBeenCalled();
        });
      });

      describe('known error code', () => {
        it('shows not enough seats error and buttons', async () => {
          await triggerErrorAlertNotEnoughSeats();

          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'NOT_ENOUGH_SEATS',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
            primaryButtonLink: addDuoProHref,
            primaryButtonText: 'Add seats',
            secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
            secondaryButtonText: 'Contact sales',
          });
          expect(scrollToElement).toHaveBeenCalled();
        });

        it('shows no seats available error and buttons', async () => {
          await triggerErrorAlertNoSeatsAvailable();

          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'NO_SEATS_AVAILABLE',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
            primaryButtonLink: addDuoProHref,
            primaryButtonText: 'Add seats',
            secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
            secondaryButtonText: 'Contact sales',
          });
          expect(scrollToElement).toHaveBeenCalled();
        });

        describe('when subscriptionPermissions returns error', () => {
          const mockError = new Error('Woops, error in permissions call');

          beforeEach(async () => {
            mockHandlerGetSubscriptionPermissionData = jest.fn().mockRejectedValueOnce(mockError);
            await triggerErrorAlertNoSeatsAvailable();
          });

          it('captures the original error for sentry', () => {
            expect(Sentry.captureException).toHaveBeenCalledWith(mockError, {
              tags: { vue_component: 'AddOnEligibleUserList' },
            });
          });

          it('emits the error', () => {
            expect(wrapper.emitted('error')).toHaveLength(1);
            expect(wrapper.emitted('error')[0][0].cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
          });

          it('shows error, sales button and add seats button', () => {
            // When clicked the button will redirect a customer and we will handle the error on CustomersPortal side
            expect(findErrorAlert().props()).toMatchObject({
              dismissible: true,
              error: 'NO_SEATS_AVAILABLE',
              errorDictionary: ADD_ON_ERROR_DICTIONARY,
              primaryButtonLink: addDuoProHref,
              primaryButtonText: 'Add seats',
              secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
              secondaryButtonText: 'Contact sales',
            });
          });

          it('scrolls to the top of the table', () => {
            expect(scrollToElement).toHaveBeenCalled();
          });
        });

        describe('when subscriptionPermissions succeeds', () => {
          describe.each`
            canAddDuoProSeats | limitedAccessReason
            ${false}          | ${'MANAGED_BY_RESELLER'}
            ${false}          | ${'RAMP_SUBSCRIPTION'}
          `(
            'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
            ({ canAddDuoProSeats, limitedAccessReason }) => {
              beforeEach(async () => {
                mockHandlerGetSubscriptionPermissionData = jest.fn().mockResolvedValue({
                  data: {
                    subscription: {
                      canAddSeats: false,
                      canRenew: false,
                      communityPlan: false,
                      canAddDuoProSeats,
                    },
                    userActionAccess: { limitedAccessReason },
                  },
                });

                await triggerErrorAlertNoSeatsAvailable();
              });

              it('shows error, sales button and no add seats button', () => {
                expect(findErrorAlert().props()).toMatchObject({
                  dismissible: true,
                  error: 'NO_SEATS_AVAILABLE',
                  errorDictionary: ADD_ON_ERROR_DICTIONARY,
                  primaryButtonLink: addDuoProHref,
                  primaryButtonText: '',
                  secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
                  secondaryButtonText: 'Contact sales',
                });
              });
            },
          );

          describe.each`
            canAddDuoProSeats | limitedAccessReason
            ${true}           | ${'MANAGED_BY_RESELLER'}
            ${true}           | ${'RAMP_SUBSCRIPTION'}
            ${false}          | ${'SOME_OTHER_ACCESS_REASON'}
          `(
            'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
            ({ canAddDuoProSeats, limitedAccessReason }) => {
              beforeEach(async () => {
                mockHandlerGetSubscriptionPermissionData = jest.fn().mockResolvedValue({
                  data: {
                    subscription: {
                      canAddSeats: false,
                      canRenew: false,
                      communityPlan: false,
                      canAddDuoProSeats,
                    },
                    userActionAccess: { limitedAccessReason },
                  },
                });

                await triggerErrorAlertNoSeatsAvailable();
              });

              it('shows error, sales button and add seats button', () => {
                expect(findErrorAlert().props()).toMatchObject({
                  dismissible: true,
                  error: 'NO_SEATS_AVAILABLE',
                  errorDictionary: ADD_ON_ERROR_DICTIONARY,
                  primaryButtonLink: addDuoProHref,
                  primaryButtonText: 'Add seats',
                  secondaryButtonLink: `${PROMO_URL}/solutions/code-suggestions/sales/`,
                  secondaryButtonText: 'Contact sales',
                });
              });
            },
          );
        });
      });
    });

    describe('bulk unassignment confirmation', () => {
      describe('successful unassignment', () => {
        beforeEach(async () => {
          await createComponent({ mountFn: mount, isBulkAddOnAssignmentEnabled: true });

          await confirmSeatUnassignment();
        });

        it('calls bulk addon unassignment mutation with appropriate params', () => {
          expect(bulkUnassignAddOnHandler).toHaveBeenCalledWith({
            addOnPurchaseId,
            userIds: [eligibleUsers[0].id, eligibleUsers[1].id],
          });
        });

        it('shows a loading state', () => {
          expect(findConfirmationModal().props().isBulkActionInProgress).toBe(true);
        });

        it('updates the cache with latest add-on assignment status', async () => {
          await waitForPromises();

          expect(getAddOnAssignmentStatusForUserFromCache(eligibleUsers[0].id)).toEqual([]);
          expect(getAddOnAssignmentStatusForUserFromCache(eligibleUsers[1].id)).toEqual([]);
        });

        it('does not show the confirmation modal on successful API call', async () => {
          await waitForPromises();

          expect(findConfirmationModal().exists()).toBe(false);
        });

        it('unselects users on successful API call', async () => {
          expect(findSelectedUsersSummary().exists()).toBe(true);

          await waitForPromises();

          expect(findSelectedUsersSummary().exists()).toBe(false);
        });

        it('shows a success alert', async () => {
          await waitForPromises();

          expect(findSuccessAlert().text()).toBe(
            '2 users have been successfully unassigned a seat.',
          );
        });
      });

      describe('unsuccessful unassignment', () => {
        const error = new Error('An error');

        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
            isBulkAddOnAssignmentEnabled: true,
            addonAssignmentBulkRemoveHandler: jest.fn().mockRejectedValue(error),
          });

          await confirmSeatUnassignment();
          await waitForPromises();
        });

        it('captures error on Sentry for generic errors', () => {
          expect(Sentry.captureException).toHaveBeenCalledWith(error);
        });

        it('does not show the confirmation modal on unsuccessful API call', () => {
          expect(findConfirmationModal().exists()).toBe(false);
        });

        it('retains user selection on unsuccessful API call', () => {
          expect(findSelectedUsersSummary().text()).toMatchInterpolatedText('2 users selected');
        });

        it('shows a generic error alert', () => {
          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'CANNOT_BULK_UNASSIGN_ADDON',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
          });
        });

        it('scrolls to the top of the table', () => {
          expect(scrollToElement).toHaveBeenCalled();
        });
      });

      describe('known error code', () => {
        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
            isBulkAddOnAssignmentEnabled: true,
            addonAssignmentBulkRemoveHandler: jest.fn().mockResolvedValue({
              data: { userAddOnAssignmentBulkRemove: noAssignmentsFoundError },
            }),
          });

          await confirmSeatUnassignment();
          await waitForPromises();
        });

        it('treats no assignments found error as success', () => {
          expect(findErrorAlert().exists()).toBe(false);
          expect(findSuccessAlert().text()).toBe(
            '2 users have been successfully unassigned a seat.',
          );
        });
      });

      describe('unknown error code', () => {
        beforeEach(async () => {
          await createComponent({
            mountFn: mount,
            isBulkAddOnAssignmentEnabled: true,
            addonAssignmentBulkRemoveHandler: jest.fn().mockResolvedValue({
              data: { userAddOnAssignmentBulkRemove: unknownErrorCodeError },
            }),
          });

          await confirmSeatUnassignment();
          await waitForPromises();
        });

        it('shows a generic error alert', () => {
          expect(findErrorAlert().props()).toMatchObject({
            dismissible: true,
            error: 'CANNOT_BULK_UNASSIGN_ADDON',
            errorDictionary: ADD_ON_ERROR_DICTIONARY,
          });
        });

        it('scrolls to the top of the table', () => {
          expect(scrollToElement).toHaveBeenCalled();
        });
      });
    });

    describe('when paginating', () => {
      beforeEach(async () => {
        createComponent({
          mountFn: mount,
          isBulkAddOnAssignmentEnabled: true,
          props: { pageInfo: pageInfoWithMorePages },
        });

        await findSelectAllUsersCheckbox().find('input').setChecked(true);
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
