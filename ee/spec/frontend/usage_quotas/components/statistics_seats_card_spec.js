import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import { visitUrl } from '~/lib/utils/url_utility';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import { PLAN_CODE_FREE } from 'ee/usage_quotas/seats/constants';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('StatisticsSeatsCard', () => {
  let wrapper;
  let subscriptionPermissionsQueryHandlerMock = jest
    .fn()
    .mockResolvedValue({ data: { subscription: null, userActionAccess: null } });

  const explorePlansPath = 'https://gitlab.com/explore-plans-path';
  const purchaseButtonLink = 'https://gitlab.com/purchase-more-seats';
  const subscriptionStartDate = '2023-03-16';
  const subscriptionEndDate = '2024-03-16';
  const defaultProps = {
    seatsUsed: 20,
    seatsOwed: 5,
    namespaceId: '4321',
    purchaseButtonLink,
  };

  const createMockApolloProvider = ({ subscriptionPlanData }) => {
    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, subscriptionPermissionsQueryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getGitlabSubscriptionQuery,
      data: subscriptionPlanData,
    });
    return mockApollo;
  };

  const createComponent = (options = {}) => {
    const { props = {}, subscriptionPlanData = {} } = options;
    const apolloProvider = createMockApolloProvider({ subscriptionPlanData });

    wrapper = shallowMountExtended(StatisticsSeatsCard, {
      propsData: { ...defaultProps, ...props },
      apolloProvider,
      provide: {
        explorePlansPath,
      },
      stubs: {
        LimitedAccessModal,
      },
    });
  };

  const findSeatsUsedBlock = () => wrapper.findByTestId('seats-used');
  const findSeatsOwedBlock = () => wrapper.findByTestId('seats-owed');
  const findPurchaseButton = () => wrapper.findByTestId('purchase-button');
  const findExplorePaidPlansButton = () => wrapper.findByTestId('explore-paid-plans');
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  describe('when `isLoading` computed value is `true`', () => {
    beforeEach(() => {
      subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
        data: {
          subscription: {
            canAddSeats: true,
            canRenew: true,
            communityPlan: false,
            canAddDuoProSeats: true,
          },
          userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
        },
      });
      createComponent();
    });

    it('renders `GlSkeletonLoader`', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('seats used block', () => {
    it('renders seats used block if seatsUsed is passed', async () => {
      createComponent();

      await waitForPromises();

      const seatsUsedBlock = findSeatsUsedBlock();

      expect(seatsUsedBlock.exists()).toBe(true);
      expect(seatsUsedBlock.text()).toContain('20');
      expect(seatsUsedBlock.findComponent(GlLink).exists()).toBe(true);
    });

    it('does not render seats used block if seatsUsed is not passed', async () => {
      createComponent({ props: { seatsUsed: null } });

      await waitForPromises();

      expect(findSeatsUsedBlock().exists()).toBe(false);
    });
  });

  describe('when there are errors', () => {
    const mockError = new Error('Something went wrong!');

    beforeEach(async () => {
      subscriptionPermissionsQueryHandlerMock = jest.fn().mockRejectedValueOnce(mockError);
      createComponent();

      await waitForPromises();
    });

    it('captures the exception', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(mockError);
    });
  });

  describe('when there are network errors', () => {
    const message = 'a network error';
    const error = new Error('A network error');

    describe('when the error array is not populated', () => {
      beforeEach(async () => {
        subscriptionPermissionsQueryHandlerMock = jest.fn().mockRejectedValueOnce(error);
        createComponent();

        await waitForPromises();
      });

      it('captures the exception', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });

    describe('when the error array is populated', () => {
      beforeEach(async () => {
        error.result = { errors: [{ message }] };
        subscriptionPermissionsQueryHandlerMock = jest.fn().mockRejectedValueOnce(error);
        createComponent();

        await waitForPromises();
      });

      it('captures the message', () => {
        expect(Sentry.captureException).toHaveBeenNthCalledWith(1, message);
      });

      it('captures the exception', () => {
        expect(Sentry.captureException).toHaveBeenNthCalledWith(2, error);
      });
    });
  });

  describe('seats owed block', () => {
    it('renders seats owed block if seatsOwed is passed', async () => {
      createComponent();

      await waitForPromises();

      const seatsOwedBlock = findSeatsOwedBlock();

      expect(seatsOwedBlock.exists()).toBe(true);
      expect(seatsOwedBlock.text()).toContain('5');
      expect(seatsOwedBlock.findComponent(GlLink).exists()).toBe(true);
    });

    it('does not render seats owed block if seatsOwed is not passed', async () => {
      createComponent({ props: { seatsOwed: null } });

      await waitForPromises();

      expect(findSeatsOwedBlock().exists()).toBe(false);
    });
  });

  describe('purchase button', () => {
    it('renders purchase button if purchase link and purchase text is passed', async () => {
      createComponent();

      await waitForPromises();

      const purchaseButton = findPurchaseButton();

      expect(purchaseButton.exists()).toBe(true);
    });

    it('does not render purchase button if purchase link is not passed', async () => {
      createComponent({ props: { purchaseButtonLink: null } });

      await waitForPromises();

      expect(findPurchaseButton().exists()).toBe(false);
    });

    it('tracks event', async () => {
      jest.spyOn(Tracking, 'event');
      createComponent();

      await waitForPromises();

      findPurchaseButton().vm.$emit('click');

      expect(Tracking.event).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'add_seats_saas',
        property: 'usage_quotas_page',
      });
    });

    it('redirects when clicked', async () => {
      createComponent();

      await waitForPromises();

      findPurchaseButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('https://gitlab.com/purchase-more-seats');
    });

    describe('when canAddSeats is not provided', () => {
      describe('with a Free Plan', () => {
        beforeEach(async () => {
          subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({});
          createComponent({
            subscriptionPlanData: {
              subscription: {
                id: '',
                endDate: subscriptionEndDate,
                startDate: subscriptionStartDate,
                plan: { code: PLAN_CODE_FREE, name: 'Free' },
              },
            },
          });

          await waitForPromises();
        });

        it('does not render the `Add more seats` button', () => {
          expect(findPurchaseButton().exists()).toBe(false);
        });

        it('does not render the modal', () => {
          expect(findLimitedAccessModal().exists()).toBe(false);
        });

        it('renders the `Explore paid plans` button', () => {
          expect(findExplorePaidPlansButton().exists()).toBe(true);
        });
      });

      describe('with no Free Plan', () => {
        beforeEach(async () => {
          createComponent();

          await waitForPromises();
        });

        it('renders the `Add more seats` button', () => {
          expect(findPurchaseButton().exists()).toBe(true);
        });

        it('does not render the modal', () => {
          expect(findLimitedAccessModal().exists()).toBe(false);
        });

        it('does not render the `Explore paid plans` button', () => {
          expect(findExplorePaidPlansButton().exists()).toBe(false);
        });
      });
    });

    describe('when canAddSeats is false', () => {
      beforeEach(async () => {
        subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
          data: {
            subscription: {
              canAddSeats: false,
              canRenew: true,
              communityPlan: false,
              canAddDuoProSeats: true,
            },
            userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
          },
        });
        createComponent({
          subscriptionPlanData: {
            subscription: {
              id: '',
              endDate: subscriptionEndDate,
              startDate: subscriptionStartDate,
              plan: { code: PLAN_CODE_FREE, name: 'Free' },
            },
          },
        });

        await waitForPromises();
      });

      it('does not render the `Add more seats` button', () => {
        expect(findPurchaseButton().exists()).toBe(false);
      });

      it('does not render the modal', () => {
        expect(findLimitedAccessModal().exists()).toBe(false);
      });

      it('renders the `Explore paid plans` button', () => {
        expect(findExplorePaidPlansButton().exists()).toBe(true);
      });

      describe('when it is a community plan', () => {
        beforeEach(() => {
          subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
            data: {
              subscription: {
                canAddSeats: false,
                canRenew: true,
                communityPlan: true,
                canAddDuoProSeats: true,
              },
              userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
            },
          });
          createComponent();

          return waitForPromises();
        });

        it('does not show the `Explore paid plans` button', () => {
          expect(findExplorePaidPlansButton().exists()).toBe(false);
        });
      });
    });
  });

  describe('limited access modal', () => {
    describe('when limitedAccessModal FF is on', () => {
      beforeEach(() => {
        gon.features = { limitedAccessModal: true };
      });

      describe.each([
        null,
        { limitedAccessReason: null },
        { limitedAccessReason: 'INVALID_REASON' },
      ])('with userActionAccess = %s', (userActionAccess) => {
        beforeEach(async () => {
          subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
            data: {
              subscription: {
                canAddSeats: false,
                canRenew: true,
                communityPlan: false,
                canAddDuoProSeats: true,
              },
              userActionAccess,
            },
          });
          createComponent();

          await waitForPromises();
        });

        it('does not render the `Add more seats` button', () => {
          expect(findPurchaseButton().exists()).toBe(false);
        });

        it('does not render the modal', () => {
          expect(findLimitedAccessModal().exists()).toBe(false);
        });
      });

      describe.each`
        canAddSeats | limitedAccessReason
        ${false}    | ${'MANAGED_BY_RESELLER'}
        ${false}    | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddSeats=$canAddSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
              data: {
                subscription: {
                  canAddSeats,
                  canRenew: true,
                  communityPlan: false,
                  canAddDuoProSeats: true,
                },
                userActionAccess: { limitedAccessReason },
              },
            });
            createComponent();
            await waitForPromises();

            findPurchaseButton().vm.$emit('click');

            await nextTick();
          });

          it('shows modal', () => {
            expect(findLimitedAccessModal().isVisible()).toBe(true);
          });

          it('sends correct props', () => {
            expect(findLimitedAccessModal().props('limitedAccessReason')).toBe(limitedAccessReason);
          });

          it('does not navigate to URL', () => {
            expect(visitUrl).not.toHaveBeenCalled();
          });

          it('does not show the `Explore paid plans` button', () => {
            expect(findExplorePaidPlansButton().exists()).toBe(false);
          });
        },
      );

      describe.each`
        canAddSeats | limitedAccessReason
        ${true}     | ${'MANAGED_BY_RESELLER'}
        ${true}     | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddSeats=$canAddSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            subscriptionPermissionsQueryHandlerMock = jest.fn().mockResolvedValue({
              data: {
                subscription: {
                  canAddSeats,
                  canRenew: true,
                  communityPlan: false,
                  canAddDuoProSeats: true,
                },
                userActionAccess: { limitedAccessReason },
              },
            });
            createComponent();
            await waitForPromises();

            findPurchaseButton().vm.$emit('click');
            await nextTick();
          });

          it('does not show modal', () => {
            expect(findLimitedAccessModal().exists()).toBe(false);
          });

          it('navigates to URL', () => {
            expect(visitUrl).toHaveBeenCalledWith(purchaseButtonLink);
          });

          it('does not show the `Explore paid plans` button', () => {
            expect(findExplorePaidPlansButton().exists()).toBe(false);
          });
        },
      );
    });

    describe('when limitedAccessModal FF is off', () => {
      beforeEach(async () => {
        gon.features = { limitedAccessModal: false };
        createComponent();

        await waitForPromises();

        findPurchaseButton().vm.$emit('click');
        await nextTick();
      });

      it('does not show modal', () => {
        expect(findLimitedAccessModal().exists()).toBe(false);
      });

      it('navigates to URL', () => {
        expect(visitUrl).toHaveBeenCalledWith('https://gitlab.com/purchase-more-seats');
      });
    });
  });
});
