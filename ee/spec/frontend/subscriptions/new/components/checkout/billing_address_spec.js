import Vue, { nextTick } from 'vue';

import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlAlert } from '@gitlab/ui';
import getBillingAccountQuery from 'ee/vue_shared/purchase_flow/graphql/queries/get_billing_account.customer.query.graphql';
import { mockTracking } from 'helpers/tracking_helper';
import { STEPS } from 'ee/subscriptions/constants';
import BillingAddress from 'ee/subscriptions/new/components/checkout/billing_address.vue';
import { getStoreConfig } from 'ee/subscriptions/new/store';
import * as types from 'ee/subscriptions/new/store/mutation_types';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import BillingAccountDetails from 'ee/vue_shared/purchase_flow/components/checkout/billing_account_details.vue';
import activateNextStepMutation from 'ee/vue_shared/purchase_flow/graphql/mutations/activate_next_step.mutation.graphql';
import { createMockApolloProvider } from 'ee_jest/vue_shared/purchase_flow/spec_helper';
import SprintfWithLinks from 'ee/vue_shared/purchase_flow/components/checkout/sprintf_with_links.vue';
import { mockBillingAccount } from 'ee_jest/subscriptions/mock_data';
import { CUSTOMERSDOT_CLIENT } from 'ee/subscriptions/buy_addons_shared/constants';
import { createMockClient } from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';
import { mountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(Vuex);
Vue.use(VueApollo);
jest.mock('~/lib/logger');

describe('Billing Address', () => {
  let store;
  let wrapper;
  let mockApolloProvider;

  const actionMocks = {
    fetchCountries: jest.fn(),
    fetchStates: jest.fn(),
  };

  async function activateNextStep() {
    await mockApolloProvider.clients.defaultClient.mutate({
      mutation: activateNextStepMutation,
    });
  }

  function createStore() {
    const { actions, ...storeConfig } = getStoreConfig();
    return new Vuex.Store({
      ...storeConfig,
      actions: { ...actions, ...actionMocks },
    });
  }

  function createComponent(options = {}) {
    const { glFeatures } = options;
    return mountExtended(BillingAddress, {
      ...options,
      provide: {
        glFeatures,
      },
    });
  }

  // Sets up all required fields
  const setupValidForm = () => {
    store.commit(types.UPDATE_COUNTRY, 'country');
    store.commit(types.UPDATE_STREET_ADDRESS_LINE_ONE, 'address line 1');
    store.commit(types.UPDATE_CITY, 'city');
    store.commit(types.UPDATE_ZIP_CODE, 'zip');
  };

  // Sets up all fields in the form group
  const setupAllFormFields = () => {
    setupValidForm();
    store.commit(types.UPDATE_STREET_ADDRESS_LINE_TWO, 'address line 2');
    store.commit(types.UPDATE_COUNTRY_STATE, 'state');
  };

  const findStep = () => wrapper.findComponent(Step);
  const findManageContactsAlert = () => wrapper.findComponent(GlAlert);
  const findManageContactsContent = () => wrapper.findComponent(SprintfWithLinks);
  const findBillingAccountDetails = () => wrapper.findComponent(BillingAccountDetails);
  const findEditOnCDotButton = () => wrapper.findByTestId('billing-address-cdot-edit');
  const findAddressForm = () => wrapper.findByTestId('checkout-billing-address-form');
  const findAddressSummary = () => wrapper.findByTestId('checkout-billing-address-summary');

  beforeEach(() => {
    store = createStore();
    mockApolloProvider = createMockApolloProvider(STEPS);
    mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
      [getBillingAccountQuery, jest.fn().mockResolvedValue({ data: { billingAccount: null } })],
    ]);
  });

  describe('mounted', () => {
    describe.each`
      billingAccountExists | billingAccountData    | stepTitle                | showAddress
      ${true}              | ${mockBillingAccount} | ${'Contact information'} | ${false}
      ${false}             | ${null}               | ${'Billing address'}     | ${true}
    `(
      'when billingAccount exists is $billingAccountExists',
      ({ billingAccountData, stepTitle, showAddress }) => {
        const handler = jest
          .fn()
          .mockResolvedValue({ data: { billingAccount: billingAccountData } });

        beforeEach(async () => {
          mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
            [getBillingAccountQuery, handler],
          ]);

          wrapper = createComponent({
            store,
            apolloProvider: mockApolloProvider,
          });
          await waitForPromises();
        });

        it('calls getBillingAccountQuery', () => {
          expect(handler).toHaveBeenCalled();
        });

        it('should load the countries', () => {
          expect(actionMocks.fetchCountries).toHaveBeenCalled();
        });

        it('shows step component', () => {
          expect(findStep().exists()).toBe(true);
        });

        it('passes correct step title', () => {
          expect(findStep().props('title')).toEqual(stepTitle);
        });

        it(`${showAddress ? 'shows' : 'does not show'} address form`, () => {
          expect(findAddressForm().exists()).toBe(showAddress);
        });

        it(`${showAddress ? 'does not show' : 'shows'} manage contact alert`, () => {
          expect(findManageContactsAlert().exists()).toBe(!showAddress);
        });

        it(`${showAddress ? 'does not show' : 'shows'} billing account details`, () => {
          expect(findBillingAccountDetails().exists()).toBe(!showAddress);
        });

        it(`${showAddress ? 'does not show' : 'shows'} edit on Customers Portal button`, () => {
          expect(findEditOnCDotButton().exists()).toBe(!showAddress);
        });
      },
    );
  });

  describe('manage contacts', () => {
    beforeEach(async () => {
      mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
        [
          getBillingAccountQuery,
          jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
        ],
      ]);

      wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
      await waitForPromises();
    });

    it('shows correct message', () => {
      expect(findManageContactsContent().props('message')).toEqual(
        'Manage the subscription and billing contacts for your billing account in the %{customersPortalLinkStart}Customers Portal%{customersPortalLinkEnd}. Learn more about %{manageContactsLinkStart}how to manage your contacts%{manageContactsLinkEnd}.',
      );
    });

    it('renders correct number of links', () => {
      expect(findManageContactsContent().props('linkObject')).toMatchObject({
        customersPortalLink: gon.billing_accounts_url,
        manageContactsLink:
          '/help/subscriptions/customers_portal#subscription-and-billing-contacts',
      });
    });
  });

  describe('billing account details', () => {
    beforeEach(async () => {
      mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
        [
          getBillingAccountQuery,
          jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
        ],
      ]);

      wrapper = createComponent({
        store,
        apolloProvider: mockApolloProvider,
      });
      await waitForPromises();
    });

    it('receives correct props', () => {
      expect(findBillingAccountDetails().props()).toMatchObject({
        billingAccount: mockBillingAccount,
      });
    });
  });

  describe('country options', () => {
    const countrySelect = () => wrapper.find('.js-country');

    beforeEach(() => {
      wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
      store.commit(types.UPDATE_COUNTRY_OPTIONS, [{ text: 'Netherlands', value: 'NL' }]);
    });

    it('render', () => {
      expect(countrySelect().exists()).toBe(true);
    });

    it('should display the select prompt', () => {
      expect(countrySelect().html()).toContain('<option value="">Select a country</option>');
    });

    it('should display the countries returned from the server', () => {
      expect(countrySelect().html()).toContain('<option value="NL">Netherlands</option>');
    });

    it('should fetch states when selecting a country', async () => {
      countrySelect().trigger('change');
      await nextTick();

      expect(actionMocks.fetchStates).toHaveBeenCalled();
    });
  });

  describe('tracking', () => {
    beforeEach(() => {
      wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
      store.commit(types.UPDATE_COUNTRY, 'US');
      store.commit(types.UPDATE_ZIP_CODE, '10467');
      store.commit(types.UPDATE_COUNTRY_STATE, 'NY');
    });

    it('tracks completion details', () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

      wrapper.findComponent(Step).vm.$emit('nextStep');

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'select_country',
        property: 'US',
      });
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'state',
        property: 'NY',
      });
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'saas_checkout_postal_code',
        property: '10467',
      });
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'continue_payment',
      });
    });

    it('tracks step edits', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

      wrapper.findComponent(Step).vm.$emit('stepEdit', 'stepID');
      await nextTick();

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'edit',
        property: 'billingAddress',
      });
    });
  });

  describe('when validating', () => {
    const isStepValid = () => findStep().props('isValid');

    describe('with a billing account', () => {
      beforeEach(async () => {
        mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
          [
            getBillingAccountQuery,
            jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
          ],
        ]);

        wrapper = createComponent({
          store,
          apolloProvider: mockApolloProvider,
        });

        await waitForPromises();
        setupValidForm();
      });

      it.each`
        caseName                             | commitFn
        ${'country is null'}                 | ${() => store.commit(types.UPDATE_COUNTRY, null)}
        ${'state is null for country that requires state'} | ${() => {
  store.commit(types.UPDATE_COUNTRY, 'US');
  store.commit(types.UPDATE_COUNTRY_STATE, null);
}}
        ${'when streetAddressLine1 is null'} | ${() => store.commit(types.UPDATE_STREET_ADDRESS_LINE_ONE, null)}
        ${'when zipcode is null'}            | ${() => store.commit(types.UPDATE_ZIP_CODE, null)}
        ${'when city is null'}               | ${() => store.commit(types.UPDATE_CITY, null)}
      `('passes true isValid prop when $caseName', async ({ commitFn }) => {
        commitFn();
        await nextTick();

        expect(isStepValid()).toBe(true);
      });
    });

    describe('without a billing account', () => {
      beforeEach(() => {
        wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
        setupValidForm();
      });

      it('should be valid when country, streetAddressLine1, city and zipCode have been entered', () => {
        expect(isStepValid()).toBe(true);
      });

      it('should be invalid when country is undefined', async () => {
        store.commit(types.UPDATE_COUNTRY, null);
        await nextTick();

        expect(isStepValid()).toBe(false);
      });

      it('should be invalid when state is undefined for countries that require state', async () => {
        store.commit(types.UPDATE_COUNTRY, 'US');
        store.commit(types.UPDATE_COUNTRY_STATE, null);
        await nextTick();

        expect(isStepValid()).toBe(false);
      });

      it(`should be valid when state is undefined for countries that don't require state`, async () => {
        store.commit(types.UPDATE_COUNTRY, 'NZL');
        store.commit(types.UPDATE_COUNTRY_STATE, null);
        await nextTick();

        expect(isStepValid()).toBe(true);
      });

      it('should be invalid when streetAddressLine1 is undefined', async () => {
        store.commit(types.UPDATE_STREET_ADDRESS_LINE_ONE, null);
        await nextTick();

        expect(isStepValid()).toBe(false);
      });

      it('should be invalid when city is undefined', async () => {
        store.commit(types.UPDATE_CITY, null);
        await nextTick();

        expect(isStepValid()).toBe(false);
      });

      it('should be invalid when zipCode is undefined', async () => {
        store.commit(types.UPDATE_ZIP_CODE, null);
        await nextTick();

        expect(isStepValid()).toBe(false);
      });
    });
  });

  describe('summary', () => {
    describe.each`
      billingAccountExists | billingAccountData    | showSummary
      ${true}              | ${mockBillingAccount} | ${false}
      ${true}              | ${null}               | ${true}
      ${false}             | ${null}               | ${true}
    `(
      'when billingAccount exists is $billingAccountExists',
      ({ billingAccountData, showSummary }) => {
        beforeEach(async () => {
          mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
            [
              getBillingAccountQuery,
              jest.fn().mockResolvedValue({ data: { billingAccount: billingAccountData } }),
            ],
          ]);

          wrapper = createComponent({ store, apolloProvider: mockApolloProvider });

          await waitForPromises();

          setupAllFormFields();
          await activateNextStep();
          await activateNextStep();
        });

        it(`${showSummary ? 'renders' : 'does not render'}`, () => {
          expect(findAddressSummary().exists()).toBe(showSummary);
        });
      },
    );

    describe('without a billing account', () => {
      beforeEach(async () => {
        wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
        setupAllFormFields();
        await activateNextStep();
        await activateNextStep();
      });

      it('should show the entered address line 1', () => {
        expect(wrapper.find('.js-summary-line-1').text()).toEqual('address line 1');
      });

      it('should show the entered address line 2', () => {
        expect(wrapper.find('.js-summary-line-2').text()).toEqual('address line 2');
      });

      it('should show the entered address city, state and zip code', () => {
        expect(wrapper.find('.js-summary-line-3').text()).toEqual('city, state zip');
      });
    });
  });

  describe('edit on customers portal button', () => {
    describe.each`
      billingAccountExists | billingAccountData    | showButton
      ${true}              | ${mockBillingAccount} | ${true}
      ${true}              | ${null}               | ${false}
      ${false}             | ${null}               | ${false}
    `(
      'when billingAccount exists is $billingAccountExists and billingAccountData is $billingAccountData',
      ({ billingAccountData, showButton }) => {
        beforeEach(async () => {
          mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
            [
              getBillingAccountQuery,
              jest.fn().mockResolvedValue({ data: { billingAccount: billingAccountData } }),
            ],
          ]);

          wrapper = createComponent({
            store,
            apolloProvider: mockApolloProvider,
          });

          await waitForPromises();

          await activateNextStep();
          await activateNextStep();
        });

        it(`${showButton ? 'renders' : 'does not render'}`, () => {
          expect(findEditOnCDotButton().exists()).toBe(showButton);
        });
      },
    );

    it('has correct attributes', async () => {
      mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
        [
          getBillingAccountQuery,
          jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
        ],
      ]);

      wrapper = createComponent({
        store,
        apolloProvider: mockApolloProvider,
      });

      await waitForPromises();

      expect(findEditOnCDotButton().text()).toEqual('Edit in Customers Portal');
      expect(findEditOnCDotButton().href).toEqual(gon.billing_accounts_url);
    });
  });

  describe('when getBillingAccountQuery responds with error', () => {
    const error = new Error('oh no!');

    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException');

      mockApolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
        [getBillingAccountQuery, jest.fn().mockRejectedValue(error)],
      ]);

      wrapper = createComponent({ store, apolloProvider: mockApolloProvider });
      await waitForPromises();
    });

    it('logs to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('logs the error to console', () => {
      expect(logError).toHaveBeenCalledWith(error);
    });
  });
});
