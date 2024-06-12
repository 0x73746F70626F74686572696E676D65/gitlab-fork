import { GlLink, GlSprintf, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { PROMO_URL, visitUrl } from 'jh_else_ce/lib/utils/url_utility';
import CodeSuggestionsInfoCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { ADD_ON_PURCHASE_FETCH_ERROR_CODE } from 'ee/usage_quotas/error_constants';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const defaultProvide = {
  addDuoProHref: 'http://customers.gitlab.com/namespaces/10/duo_pro_seats',
  isSaaS: true,
  subscriptionName: null,
};

describe('CodeSuggestionsInfoCard', () => {
  let wrapper;

  const defaultProps = { groupId: '4321' };
  const defaultApolloData = {
    subscription: {
      canAddSeats: false,
      canRenew: false,
      communityPlan: false,
      canAddDuoProSeats: true,
    },
    userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
  };

  let queryHandlerMock = jest.fn().mockResolvedValue({
    data: defaultApolloData,
  });

  const findCodeSuggestionsDescription = () => wrapper.findByTestId('description');
  const findCodeSuggestionsLearnMoreLink = () => wrapper.findComponent(GlLink);
  const findCodeSuggestionsInfoTitle = () => wrapper.findByTestId('title');
  const findAddSeatsButton = () => wrapper.findComponent(GlButton);
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  const createComponent = (options = {}) => {
    const { props = {}, provide = {} } = options;

    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, queryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    wrapper = shallowMountExtended(CodeSuggestionsInfoCard, {
      propsData: { ...defaultProps, ...props },
      provide: { ...defaultProvide, ...provide },
      apolloProvider: mockApollo,
      stubs: {
        GlSprintf,
        LimitedAccessModal,
        UsageStatistics: {
          template: `
            <div>
                <slot name="actions"></slot>
                <slot name="description"></slot>
                <slot name="additional-info"></slot>
            </div>
            `,
        },
      },
    });
  };

  describe('when `isLoading` computed value is `true`', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders `GlSkeletonLoader`', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('Add Seats button is not shown while loading', () => {
      createComponent();

      expect(findAddSeatsButton().exists()).toBe(false);
    });
  });

  describe('general rendering', () => {
    beforeEach(async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    describe('with Duo Pro add-on enabled', () => {
      beforeEach(async () => {
        createComponent({ props: { duoTier: 'pro' } });

        // wait for apollo to load
        await waitForPromises();
      });

      it('renders the title text', () => {
        expect(findCodeSuggestionsInfoTitle().text()).toBe('GitLab Duo Pro');
      });
    });

    describe('with Duo Enterprise add-on enabled', () => {
      beforeEach(async () => {
        createComponent({ props: { duoTier: 'enterprise' } });

        // wait for apollo to load
        await waitForPromises();
      });

      it('renders the title text', () => {
        expect(findCodeSuggestionsInfoTitle().text()).toBe('GitLab Duo Enterprise');
      });
    });

    it('renders the description text', () => {
      expect(findCodeSuggestionsDescription().text()).toBe(
        "Code Suggestions uses generative AI to suggest code while you're developing.",
      );
    });

    it('renders the learn more link', () => {
      expect(findCodeSuggestionsLearnMoreLink().attributes('href')).toBe(
        `${PROMO_URL}/solutions/code-suggestions/`,
      );
    });
  });

  describe('add seats button', () => {
    it('is rendered after apollo is loaded', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();
      expect(findAddSeatsButton().exists()).toBe(true);
    });

    describe('when subscriptionPermissions returns error', () => {
      const mockError = new Error('Woops, error in permissions call');
      beforeEach(async () => {
        queryHandlerMock = jest.fn().mockRejectedValueOnce(mockError);
        createComponent();

        await waitForPromises();
      });

      it('captures the ooriginal error in subscriptionPermissions call', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(mockError, {
          tags: { vue_component: 'CodeSuggestionsUsageInfoCard' },
        });
      });

      it('emits the error', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
        const caughtError = wrapper.emitted('error')[0][0];
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });

      it('shows the button', () => {
        // When clicked the button will redirect a customer and we will handle the error on CustomersPortal side
        expect(findAddSeatsButton().exists()).toBe(true);
      });
    });

    describe('tracking', () => {
      beforeEach(() => {
        jest.spyOn(Tracking, 'event');
      });

      it.each`
        isSaaS   | label
        ${true}  | ${'add_duo_pro_saas'}
        ${false} | ${'add_duo_pro_sm'}
      `('tracks the click with correct labels', async ({ isSaaS, label }) => {
        createComponent({ provide: { isSaaS } });
        await waitForPromises();
        findAddSeatsButton().vm.$emit('click');
        expect(Tracking.event).toHaveBeenCalledWith(
          undefined,
          'click_button',
          expect.objectContaining({
            property: 'usage_quotas_page',
            label,
          }),
        );
      });
    });

    describe('limited access modal', () => {
      describe.each`
        canAddDuoProSeats | limitedAccessReason
        ${false}          | ${'MANAGED_BY_RESELLER'}
        ${false}          | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddDuoProSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            queryHandlerMock = jest.fn().mockResolvedValue({
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
            createComponent();
            await waitForPromises();

            findAddSeatsButton().vm.$emit('click');

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
        },
      );

      describe.each`
        canAddDuoProSeats | limitedAccessReason
        ${true}           | ${'MANAGED_BY_RESELLER'}
        ${true}           | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddDuoProSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            queryHandlerMock = jest.fn().mockResolvedValue({
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
            createComponent();
            await waitForPromises();

            findAddSeatsButton().vm.$emit('click');
            await nextTick();
          });

          it('does not show modal', () => {
            expect(findLimitedAccessModal().exists()).toBe(false);
          });

          it('navigates to URL', () => {
            expect(visitUrl).toHaveBeenCalledWith(defaultProvide.addDuoProHref);
          });
        },
      );
    });
  });
});
