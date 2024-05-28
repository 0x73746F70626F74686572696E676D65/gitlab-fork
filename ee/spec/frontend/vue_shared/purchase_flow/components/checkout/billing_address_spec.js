import Vue from 'vue';
import { merge } from 'lodash';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import getBillingAccountQuery from 'ee/vue_shared/purchase_flow/graphql/queries/get_billing_account.customer.query.graphql';
import { gitLabResolvers } from 'ee/subscriptions/buy_addons_shared/graphql/resolvers';
import { STEPS } from 'ee/subscriptions/constants';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import BillingAddress from 'ee/vue_shared/purchase_flow/components/checkout/billing_address.vue';
import SprintfWithLinks from 'ee/vue_shared/purchase_flow/components/checkout/sprintf_with_links.vue';
import Step from 'ee/vue_shared/purchase_flow/components/step.vue';
import { mockBillingAccount, stateData as initialStateData } from 'ee_jest/subscriptions/mock_data';
import { createMockApolloProvider } from 'ee_jest/vue_shared/purchase_flow/spec_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';
import { CUSTOMERSDOT_CLIENT } from 'ee/subscriptions/buy_addons_shared/constants';
import { createMockClient } from 'helpers/mock_apollo_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';
import BillingAccountDetails from 'ee/vue_shared/purchase_flow/components/checkout/billing_account_details.vue';

Vue.use(VueApollo);
jest.mock('~/lib/logger');

describe('Billing Address', () => {
  let wrapper;
  let updateState = jest.fn();
  let apolloProvider;

  const findCountrySelect = () => wrapper.findByTestId('country');

  const findStep = () => wrapper.findComponent(Step);
  const findManageContactsAlert = () => wrapper.findComponent(GlAlert);
  const findManageContactsContent = () => wrapper.findComponent(SprintfWithLinks);
  const findBillingAccountDetails = () => wrapper.findComponent(BillingAccountDetails);
  const findAddressForm = () => wrapper.findByTestId('checkout-billing-address-form');
  const findAddressSummary = () => wrapper.findByTestId('checkout-billing-address-summary');
  const findEditOnCDotButton = () => wrapper.findByTestId('billing-address-cdot-edit');

  const createComponent = async (
    apolloLocalStateData = {},
    billingAccountFn = jest.fn().mockResolvedValue({ data: { billingAccount: null } }),
    glFeatures = {},
  ) => {
    const apolloResolvers = {
      Query: {
        countries: jest.fn().mockResolvedValue([
          { id: 'NL', name: 'Netherlands', flag: 'NL', internationalDialCode: '31' },
          { id: 'US', name: 'United States of America', flag: 'US', internationalDialCode: '1' },
        ]),
        states: jest.fn().mockResolvedValue([{ id: 'CA', name: 'California' }]),
      },
      Mutation: { updateState },
    };

    apolloProvider = createMockApolloProvider(STEPS, STEPS[1], {
      ...gitLabResolvers,
      ...apolloResolvers,
    });
    apolloProvider.clients.defaultClient.cache.writeQuery({
      query: stateQuery,
      data: merge({}, initialStateData, apolloLocalStateData),
    });
    apolloProvider.clients[CUSTOMERSDOT_CLIENT] = createMockClient([
      [getBillingAccountQuery, billingAccountFn],
    ]);

    wrapper = mountExtended(BillingAddress, {
      apolloProvider,
      provide: {
        glFeatures,
      },
    });

    await waitForPromises();
  };

  describe.each`
    billingAccountExists | billingAccountData    | stepTitle                | showAddress
    ${true}              | ${mockBillingAccount} | ${'Contact information'} | ${false}
    ${false}             | ${null}               | ${'Billing address'}     | ${true}
  `(
    'when billingAccount exists is $billingAccountExists',
    ({ billingAccountData, stepTitle, showAddress }) => {
      const handler = jest.fn().mockResolvedValue({ data: { billingAccount: billingAccountData } });

      beforeEach(async () => {
        await createComponent({}, handler);
      });

      it('calls getBillingAccountQuery', () => {
        expect(handler).toHaveBeenCalled();
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

  describe('manage contacts', () => {
    beforeEach(async () => {
      await createComponent(
        {},
        jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
      );
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
      await createComponent(
        {},
        jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
      );
    });

    it('receives correct props', () => {
      expect(findBillingAccountDetails().props()).toMatchObject({
        billingAccount: mockBillingAccount,
      });
    });
  });

  describe('country options', () => {
    const countrySelect = () => wrapper.find('.js-country');

    beforeEach(async () => {
      await createComponent();
    });

    it('displays the countries returned from the server', () => {
      expect(countrySelect().html()).toContain('<option value="NL">Netherlands</option>');
    });
  });

  describe('validations', () => {
    const isStepValid = () => wrapper.findComponent(Step).props('isValid');
    const customerData = {
      country: 'NL',
      address1: 'address line 1',
      address2: 'address line 2',
      city: 'city',
      zipCode: 'zip',
      state: null,
    };

    describe('with a billing account', () => {
      it.each`
        caseName                                           | addressData
        ${'country is null'}                               | ${{ country: null }}
        ${'when streetAddressLine1 is null'}               | ${{ address1: null }}
        ${'when city is null'}                             | ${{ city: null }}
        ${'when zipcode is null'}                          | ${{ zipCode: null }}
        ${'state is null for country that requires state'} | ${{ country: 'US' }}
      `('passes true isValid prop when $caseName', async ({ addressData }) => {
        await createComponent({ customer: { ...customerData, addressData } });

        expect(isStepValid()).toBe(true);
      });
    });

    describe('without a billing account', () => {
      it('is valid when country, streetAddressLine1, city and zipCode have been entered', async () => {
        await createComponent({ customer: customerData });

        expect(isStepValid()).toBe(true);
      });

      it('is invalid when country is undefined', async () => {
        await createComponent({ customer: { ...customerData, country: null } });

        expect(isStepValid()).toBe(false);
      });

      it('is invalid when streetAddressLine1 is undefined', async () => {
        await createComponent({ customer: { ...customerData, address1: null } });

        expect(isStepValid()).toBe(false);
      });

      it('is invalid when city is undefined', async () => {
        await createComponent({ customer: { ...customerData, city: null } });

        expect(isStepValid()).toBe(false);
      });

      it('is invalid when zipCode is undefined', async () => {
        await createComponent({ customer: { ...customerData, zipCode: null } });

        expect(isStepValid()).toBe(false);
      });

      it('is invalid when state is undefined for countries that require state', async () => {
        await createComponent({ customer: { ...customerData, country: 'US' } });

        expect(isStepValid()).toBe(false);
      });

      it(`is valid when state is undefined for countries that don't require state`, async () => {
        await createComponent({ customer: { ...customerData, country: 'NL' } });

        expect(isStepValid()).toBe(true);
      });

      it(`is valid when state exists for countries that require state`, async () => {
        await createComponent({ customer: { ...customerData, country: 'US', state: 'CA' } });

        expect(isStepValid()).toBe(true);
      });
    });
  });

  describe('summary', () => {
    describe.each`
      billingAccountExists | billingAccountData    | showSummary
      ${true}              | ${mockBillingAccount} | ${false}
      ${false}             | ${null}               | ${true}
    `(
      'when billingAccount exists is $billingAccountExists',
      ({ billingAccountData, showSummary }) => {
        beforeEach(async () => {
          await createComponent(
            {
              customer: {
                country: 'US',
                address1: 'address line 1',
                address2: 'address line 2',
                city: 'city',
                zipCode: 'zip',
                state: 'CA',
              },
            },
            jest.fn().mockResolvedValue({ data: { billingAccount: billingAccountData } }),
          );
        });

        it(`${showSummary ? 'renders' : 'does not render'}`, () => {
          expect(findAddressSummary().exists()).toBe(showSummary);
        });
      },
    );

    describe('without billing account', () => {
      beforeEach(async () => {
        await createComponent({
          customer: {
            country: 'US',
            address1: 'address line 1',
            address2: 'address line 2',
            city: 'city',
            zipCode: 'zip',
            state: 'CA',
          },
        });
      });

      it('should show the entered address line 1', () => {
        expect(wrapper.find('.js-summary-line-1').text()).toBe('address line 1');
      });

      it('should show the entered address line 2', () => {
        expect(wrapper.find('.js-summary-line-2').text()).toBe('address line 2');
      });

      it('should show the entered address city, state and zip code', () => {
        expect(wrapper.find('.js-summary-line-3').text()).toBe('city, US California zip');
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
          await createComponent(
            {},
            jest.fn().mockResolvedValue({ data: { billingAccount: billingAccountData } }),
          );

          await waitForPromises();
        });

        it(`${showButton ? 'renders' : 'does not render'}`, () => {
          expect(findEditOnCDotButton().exists()).toBe(showButton);
        });
      },
    );

    it('has correct attributes', async () => {
      await createComponent(
        {},
        jest.fn().mockResolvedValue({ data: { billingAccount: mockBillingAccount } }),
      );

      await waitForPromises();

      expect(findEditOnCDotButton().text()).toEqual('Edit in Customers Portal');
      expect(findEditOnCDotButton().href).toEqual(gon.billing_accounts_url);
    });
  });

  describe('when the mutation fails', () => {
    const error = new Error('Yikes!');

    beforeEach(async () => {
      updateState = jest.fn().mockRejectedValue(error);
      await createComponent({
        customer: { country: 'US' },
      });
    });

    it('emits an error', async () => {
      findCountrySelect().vm.$emit('input', 'IT');

      await waitForPromises();

      expect(wrapper.emitted(PurchaseEvent.ERROR)).toEqual([[error]]);
    });
  });

  describe('when getBillingAccountQuery responds with error', () => {
    const error = new Error('oh no!');

    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException');

      wrapper = await createComponent({}, jest.fn().mockRejectedValue(error));
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
