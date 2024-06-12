import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/self_managed_add_on_eligible_users.query.graphql';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import {
  eligibleSMUsers,
  pageInfoWithMorePages,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('Add On Eligible User List', () => {
  let wrapper;

  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/1';
  const error = new Error('Error');
  const addOnEligibleUsersResponse = {
    data: {
      selfManagedAddOnEligibleUsers: {
        nodes: eligibleSMUsers,
        pageInfo: pageInfoWithMorePages,
        __typename: 'AddOnUserConnection',
      },
    },
  };
  const defaultQueryVariables = {
    addOnType: 'CODE_SUGGESTIONS',
    addOnPurchaseIds: [addOnPurchaseId],
    first: 20,
    last: null,
    after: null,
    before: null,
  };

  const addOnEligibleUsersDataHandler = jest.fn().mockResolvedValue(addOnEligibleUsersResponse);
  const addOnEligibleUsersErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) =>
    createMockApollo([[getAddOnEligibleUsers, handler]]);

  const createComponent = (handler = addOnEligibleUsersDataHandler) => {
    wrapper = extendedWrapper(
      shallowMount(SelfManagedAddOnEligibleUserList, {
        apolloProvider: createMockApolloProvider(handler),
        propsData: {
          addOnPurchaseId,
        },
      }),
    );

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
      const expectedProps = {
        addOnPurchaseId,
        duoTier: 'pro',
        isLoading: false,
        pageInfo: pageInfoWithMorePages,
        search: '',
        users: eligibleSMUsers,
      };

      expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
    });

    it('calls addOnEligibleUsers query with appropriate params', () => {
      expect(addOnEligibleUsersDataHandler).toHaveBeenCalledWith(defaultQueryVariables);
    });

    describe('when there is an error fetching add on eligible users', () => {
      beforeEach(() => {
        return createComponent(addOnEligibleUsersErrorHandler);
      });

      it('displays add-on eligible user list', () => {
        const expectedProps = {
          addOnPurchaseId,
          duoTier: 'pro',
          isLoading: false,
          pageInfo: undefined,
          search: '',
          users: [],
        };

        expect(findAddOnEligibleUserList().props()).toEqual(expectedProps);
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

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays add-on eligible user list in loading state', () => {
      expect(findAddOnEligibleUserList().props('isLoading')).toBe(true);
    });
  });

  describe('pagination', () => {
    const { startCursor, endCursor } = pageInfoWithMorePages;

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

  describe('search', () => {
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
  });
});
