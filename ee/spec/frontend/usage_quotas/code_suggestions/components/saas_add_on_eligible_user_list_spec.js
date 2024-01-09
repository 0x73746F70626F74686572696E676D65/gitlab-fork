import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { mockPaginatedAddOnEligibleUsers } from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import { SORT_OPTIONS } from 'ee/usage_quotas/code_suggestions/constants';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('Add On Eligible User List', () => {
  let enableAddOnUsersFiltering = false;
  let wrapper;

  const fullPath = 'namespace/full-path';
  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const error = new Error('Error');
  const defaultQueryVariables = {
    fullPath,
    addOnType: 'CODE_SUGGESTIONS',
    addOnPurchaseIds: [addOnPurchaseId],
    first: 20,
    last: null,
    after: null,
    before: null,
    sort: null,
  };

  const addOnEligibleUsersDataHandler = jest
    .fn()
    .mockResolvedValue(mockPaginatedAddOnEligibleUsers);
  const addOnEligibleUsersErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) =>
    createMockApollo([[getAddOnEligibleUsers, handler]]);

  const createComponent = (handler = addOnEligibleUsersDataHandler) => {
    wrapper = shallowMountExtended(SaasAddOnEligibleUserList, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        addOnPurchaseId,
      },
      provide: {
        fullPath,
        glFeatures: {
          enableAddOnUsersFiltering,
        },
      },
    });
    return waitForPromises();
  };

  const findAddOnEligibleUserList = () => wrapper.findComponent(AddOnEligibleUserList);
  const findAddOnEligibleUsersFetchError = () =>
    wrapper.findByTestId('add-on-eligible-users-fetch-error');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);

  describe('add-on eligible user list', () => {
    beforeEach(() => {
      return createComponent();
    });

    it('displays add-on eligible user list', () => {
      const {
        pageInfo,
        nodes: users,
      } = mockPaginatedAddOnEligibleUsers.data.namespace.addOnEligibleUsers;
      const expectedProps = {
        addOnPurchaseId,
        isLoading: false,
        pageInfo,
        users,
        search: '',
      };

      expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
    });

    it('calls addOnEligibleUsers query with appropriate params', () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(defaultQueryVariables);
    });

    it('passes the correct sort options to <search-and-sort-bar>', () => {
      expect(findSearchAndSortBar().props('sortOptions')).toStrictEqual([]);
    });

    describe('when enableAddOnUsersFiltering is enabled', () => {
      beforeEach(() => {
        enableAddOnUsersFiltering = true;
        return createComponent();
      });

      it('passes the correct sort options to <search-and-sort-bar>', () => {
        expect(findSearchAndSortBar().props('sortOptions')).toStrictEqual(SORT_OPTIONS);
      });
    });

    describe('when there is an error fetching add on eligible users', () => {
      beforeEach(() => {
        return createComponent(addOnEligibleUsersErrorHandler);
      });

      it('does not display loading state for add-on eligible user list', () => {
        expect(findAddOnEligibleUserList().props('isLoading')).toBe(false);
      });

      it('sends the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException.mock.calls[0][0]).toEqual(error);
      });

      it('shows an error alert', () => {
        const expectedProps = {
          dismissible: true,
          error: ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
          errorDictionary: ADD_ON_ERROR_DICTIONARY,
        };

        expect(findAddOnEligibleUsersFetchError().props()).toEqual(
          expect.objectContaining(expectedProps),
        );
      });

      it('clears error alert when dismissed', async () => {
        findAddOnEligibleUsersFetchError().vm.$emit('dismiss');

        await nextTick();

        expect(findAddOnEligibleUsersFetchError().exists()).toBe(false);
      });
    });
  });

  describe('when loading', () => {
    it('displays add-on eligible user list in loading state', () => {
      createComponent();

      expect(findAddOnEligibleUserList().props('isLoading')).toBe(true);
    });
  });

  describe('pagination', () => {
    const {
      startCursor,
      endCursor,
    } = mockPaginatedAddOnEligibleUsers.data.namespace.addOnEligibleUsers.pageInfo.endCursor;
    beforeEach(() => {
      return createComponent();
    });

    it('fetches next page of users on next', async () => {
      findAddOnEligibleUserList().vm.$emit('next', endCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        after: endCursor,
      });
    });

    it('fetches prev page of users on prev', async () => {
      findAddOnEligibleUserList().vm.$emit('prev', startCursor);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        first: null,
        last: 20,
        before: startCursor,
      });
    });
  });

  describe('with filters and sort options', () => {
    const filterOptions = { search: 'test' };

    beforeEach(() => {
      return createComponent();
    });

    it('fetches users list matching the search term', async () => {
      findSearchAndSortBar().vm.$emit('onFilter', filterOptions);
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        ...filterOptions,
      });
    });

    it('fetches users list with the correct sorting values', async () => {
      findSearchAndSortBar().vm.$emit('onSort', 'LAST_ACTIVITY_ON_DESC');
      await waitForPromises();

      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        sort: 'LAST_ACTIVITY_ON_DESC',
      });
    });
  });
});
