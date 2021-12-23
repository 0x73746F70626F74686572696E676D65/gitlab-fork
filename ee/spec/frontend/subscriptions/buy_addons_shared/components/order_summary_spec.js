import { createLocalVue } from '@vue/test-utils';
import { merge } from 'lodash';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OrderSummary from 'ee/subscriptions/buy_addons_shared/components/order_summary.vue';
import subscriptionsResolvers from 'ee/subscriptions/buy_addons_shared/graphql/resolvers';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import purchaseFlowResolvers from 'ee/vue_shared/purchase_flow/graphql/resolvers';
import {
  mockStoragePlans,
  mockParsedNamespaces,
  mockOrderPreview,
  stateData as mockStateData,
} from 'ee_jest/subscriptions/mock_data';
import createMockApollo, { createMockClient } from 'helpers/mock_apollo_helper';

import orderPreviewQuery from 'ee/subscriptions/graphql/queries/order_preview.customer.query.graphql';
import { CUSTOMERSDOT_CLIENT } from 'ee/subscriptions/buy_addons_shared/constants';

const localVue = createLocalVue();
localVue.use(VueApollo);

describe('Order Summary', () => {
  const resolvers = { ...purchaseFlowResolvers, ...subscriptionsResolvers };
  const selectedNamespaceId = mockParsedNamespaces[0].id;
  const initialStateData = {
    eligibleNamespaces: mockParsedNamespaces,
    selectedNamespaceId,
    subscription: {},
  };
  let wrapper;

  const findAmount = () => wrapper.findByTestId('amount');
  const findTitle = () => wrapper.findByTestId('title');

  const createMockApolloProvider = (stateData = {}, mockRequest = {}) => {
    const mockApollo = createMockApollo([], resolvers);
    const data = merge({}, mockStateData, initialStateData, stateData);
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: stateQuery,
      data,
    });
    mockApollo.clients[CUSTOMERSDOT_CLIENT] = createMockClient([[orderPreviewQuery, mockRequest]]);
    return mockApollo;
  };

  const createComponent = (apolloProvider, props) => {
    wrapper = shallowMountExtended(OrderSummary, {
      localVue,
      apolloProvider,
      propsData: {
        plan: mockStoragePlans[0],
        title: "%{name}'s storage subscription",
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('the default plan', () => {
    beforeEach(() => {
      const apolloProvider = createMockApolloProvider({ subscription: { quantity: 1 } });
      createComponent(apolloProvider);
    });

    it('displays the title', () => {
      expect(findTitle().text()).toMatchInterpolatedText("Gitlab Org's storage subscription");
    });
  });

  describe('when quantity is greater than zero', () => {
    beforeEach(() => {
      const apolloProvider = createMockApolloProvider({ subscription: { quantity: 3 } });
      createComponent(apolloProvider);
    });

    it('renders amount', () => {
      expect(findAmount().text()).toBe('$180');
    });
  });

  describe('when quantity is less than or equal to zero', () => {
    beforeEach(() => {
      const apolloProvider = createMockApolloProvider({
        subscription: { quantity: 0 },
      });
      createComponent(apolloProvider);
    });

    it('does not render amount', () => {
      expect(findAmount().text()).toBe('-');
    });
  });

  describe('when subscription has expiration date', () => {
    describe('calls api that returns prorated amount', () => {
      beforeEach(() => {
        const orderPreviewQueryMock = jest
          .fn()
          .mockResolvedValue({ data: { orderPreview: mockOrderPreview } });
        const apolloProvider = createMockApolloProvider(
          { subscription: { quantity: 1 } },
          orderPreviewQueryMock,
        );
        createComponent(apolloProvider, { purchaseHasExpiration: true });
      });

      it('renders prorated amount', () => {
        expect(findAmount().text()).toBe('$59.67');
      });
    });

    describe('calls api that returns empty value', () => {
      beforeEach(() => {
        const orderPreviewQueryMock = jest.fn().mockResolvedValue({ data: { orderPreview: null } });
        const apolloProvider = createMockApolloProvider(
          { subscription: { quantity: 1 } },
          orderPreviewQueryMock,
        );
        createComponent(apolloProvider, { purchaseHasExpiration: true });
      });

      it('renders amount from the state', () => {
        expect(findAmount().text()).toBe('$60');
      });
    });

    describe('calls api that returns no data', () => {
      beforeEach(() => {
        jest.spyOn(console, 'error').mockImplementation(() => {});
        const orderPreviewQueryMock = jest.fn().mockResolvedValue({ data: null });
        const apolloProvider = createMockApolloProvider(
          { subscription: { quantity: 1 } },
          orderPreviewQueryMock,
        );
        createComponent(apolloProvider, { purchaseHasExpiration: true });
      });

      it('renders amount from the state', () => {
        expect(findAmount().text()).toBe('$60');
      });
    });

    describe('when api is loading', () => {
      beforeEach(() => {
        const orderPreviewQueryMock = jest.fn().mockResolvedValue(new Promise(() => {}));
        const apolloProvider = createMockApolloProvider(
          { subscription: { quantity: 1 } },
          orderPreviewQueryMock,
        );
        createComponent(apolloProvider, { purchaseHasExpiration: true });
      });

      it('does not render amount when api is loading', () => {
        expect(findAmount().text()).toBe('-');
      });
    });
  });
});
