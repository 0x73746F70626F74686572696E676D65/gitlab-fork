import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import addOnPurchaseQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchase.query.graphql';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import CodeSuggestionsInfo from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_statistics_card.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import {
  noAssignedAddonData,
  noAssignedEnterpriseAddonData,
  noPurchasedAddonData,
  purchasedAddonFuzzyData,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('GitLab Duo Usage', () => {
  let wrapper;

  const error = new Error('Something went wrong');

  const noAssignedAddonDataHandler = jest.fn().mockResolvedValue(noAssignedAddonData);
  const noAssignedEnterpriseAddonDataHandler = jest
    .fn()
    .mockResolvedValue(noAssignedEnterpriseAddonData);
  const noPurchasedAddonDataHandler = jest.fn().mockResolvedValue(noPurchasedAddonData);
  const purchasedAddonFuzzyDataHandler = jest.fn().mockResolvedValue(purchasedAddonFuzzyData);
  const purchasedAddonErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler = noPurchasedAddonDataHandler) =>
    createMockApollo([[addOnPurchaseQuery, handler]]);

  const findCodeSuggestionsIntro = () => wrapper.findComponent(CodeSuggestionsIntro);
  const findCodeSuggestionsInfo = () => wrapper.findComponent(CodeSuggestionsInfo);
  const findCodeSuggestionsStatistics = () => wrapper.findComponent(CodeSuggestionsStatisticsCard);
  const findCodeSuggestionsSubtitle = () => wrapper.findByTestId('code-suggestions-subtitle');
  const findCodeSuggestionsTitle = () => wrapper.findByTestId('code-suggestions-title');
  const findSaasAddOnEligibleUserList = () => wrapper.findComponent(SaasAddOnEligibleUserList);
  const findSelfManagedAddOnEligibleUserList = () =>
    wrapper.findComponent(SelfManagedAddOnEligibleUserList);
  const findErrorAlert = () => wrapper.findByTestId('add-on-purchase-fetch-error');

  const createComponent = ({ handler, provideProps } = {}) => {
    wrapper = shallowMountExtended(CodeSuggestionsUsage, {
      provide: {
        isSaaS: true,
        ...provideProps,
      },
      apolloProvider: createMockApolloProvider(handler),
    });

    return waitForPromises();
  };

  describe('when no group id prop is provided', () => {
    beforeEach(() => {
      createComponent({ handler: noAssignedAddonDataHandler });
    });
    it('calls addOnPurchase query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        addOnType: 'CODE_SUGGESTIONS',
        namespaceId: null,
      });
    });
  });

  describe('when group id prop is provided', () => {
    beforeEach(() => {
      createComponent({
        handler: noAssignedAddonDataHandler,
        provideProps: { groupId: '289561' },
      });
    });
    it('calls addOnPurchase query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        addOnType: 'CODE_SUGGESTIONS',
        namespaceId: 'gid://gitlab/Group/289561',
      });
    });
  });

  describe('with no code suggestions data', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent();
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({ provideProps: { isSaaS: false } });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });
  });

  describe('with code suggestions data', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent({
          handler: noAssignedAddonDataHandler,
          provideProps: { groupId: '289561' },
        });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      describe('with Duo Pro add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            handler: noAssignedAddonDataHandler,
            provideProps: { groupId: '289561' },
          });
        });

        it('renders code suggestions statistics card for duo pro', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: 'pro',
          });
        });

        it('renders code suggestions info card for duo pro', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: '289561',
            duoTier: 'pro',
          });
        });
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            handler: noAssignedEnterpriseAddonDataHandler,
            provideProps: { groupId: '289561' },
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: 'enterprise',
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: '289561',
            duoTier: 'enterprise',
          });
        });
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          handler: noAssignedAddonDataHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('GitLab Duo Pro');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          'Manage seat assignments for GitLab Duo Pro across your instance.',
        );
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('renders code suggestions statistics card', () => {
        expect(findCodeSuggestionsStatistics().props()).toEqual({
          usageValue: 0,
          totalValue: 20,
          duoTier: 'pro',
        });
      });

      it('renders code suggestions info card', () => {
        expect(findCodeSuggestionsInfo().exists()).toBe(true);
      });
    });
  });

  describe('add on eligible user list', () => {
    it('renders addon user list for SaaS instance for SaaS', async () => {
      createComponent({ handler: noAssignedAddonDataHandler, provideProps: { isSaaS: true } });
      await waitForPromises();

      expect(findSaasAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        duoTier: 'pro',
      });
    });

    it('renders addon user list for SM instance for SM', async () => {
      createComponent({ handler: noAssignedAddonDataHandler, provideProps: { isSaaS: false } });
      await waitForPromises();

      expect(findSelfManagedAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
      });
    });
  });

  describe('with fuzzy code suggestions data', () => {
    beforeEach(() => {
      return createComponent({ handler: purchasedAddonFuzzyDataHandler });
    });

    it('renders code suggestions intro', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(true);
    });
  });

  describe('with errors', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent({ handler: purchasedAddonErrorHandler });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          handler: purchasedAddonErrorHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().text()).toBe('GitLab Duo Pro');
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          'Manage seat assignments for GitLab Duo Pro across your instance.',
        );
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });
  });
});
