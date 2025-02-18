import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlLink, GlSprintf, GlProgressBar } from '@gitlab/ui';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import StorageUsageOverviewCard from '~/usage_quotas/storage/components/storage_usage_overview_card.vue';
import NamespaceLimitsStorageUsageOverviewCard from 'ee/usage_quotas/storage/components/namespace_limits_storage_usage_overview_card.vue';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from 'ee/usage_quotas/storage/components/namespace_limits_total_storage_available_breakdown_card.vue';
import NoLimitsPurchasedStorageBreakdownCard from 'ee/usage_quotas/storage/components/no_limits_purchased_storage_breakdown_card.vue';
import ProjectLimitsExcessStorageBreakdownCard from 'ee/usage_quotas/storage/components/project_limits_excess_storage_breakdown_card.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StorageUsageStatistics from 'ee/usage_quotas/storage/components/storage_usage_statistics.vue';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { namespace } from 'jest/usage_quotas/storage/mock_data';
import { defaultNamespaceProvideValues } from '../mock_data';

Vue.use(VueApollo);

const defaultApolloData = {
  subscription: {
    canAddSeats: false,
    canRenew: false,
    communityPlan: false,
    canAddDuoProSeats: true,
  },
  userActionAccess: { limitedAccessReason: 'RAMP_SUBSCRIPTION' },
};

describe('StorageUsageStatistics', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ props = {}, provide = {}, apolloData = defaultApolloData } = {}) => {
    const queryHandlerMock = jest.fn().mockResolvedValue({
      data: apolloData,
    });
    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, queryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    wrapper = shallowMountExtended(StorageUsageStatistics, {
      propsData: {
        additionalPurchasedStorageSize: namespace.additionalPurchasedStorageSize,
        usedStorage: namespace.rootStorageStatistics.storageSize,
        loading: false,
        ...props,
      },
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      apolloProvider: mockApollo,
      stubs: {
        StorageUsageOverviewCard,
        NumberToHumanSize,
        GlSprintf,
        GlButton,
        GlLink,
        GlProgressBar,
      },
    });
  };

  const findStorageUsageOverviewCard = () => wrapper.findComponent(StorageUsageOverviewCard);
  const findNamespaceLimitsStorageUsageOverviewCard = () =>
    wrapper.findComponent(NamespaceLimitsStorageUsageOverviewCard);
  const findNamespaceLimitsTotalStorageAvailableBreakdownCard = () =>
    wrapper.findComponent(NamespaceLimitsTotalStorageAvailableBreakdownCard);
  const findProjectLimitsExcessStorageBreakdownCard = () =>
    wrapper.findComponent(ProjectLimitsExcessStorageBreakdownCard);
  const findNoLimitsPurchasedStorageBreakdownCard = () =>
    wrapper.findComponent(NoLimitsPurchasedStorageBreakdownCard);
  const findOverviewSubtitle = () => wrapper.findByTestId('overview-subtitle');
  const findPurchaseButton = () => wrapper.findComponent(GlButton);
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  describe('namespace overview section', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the namespace storage overview subtitle', () => {
      expect(findOverviewSubtitle().text()).toBe('Namespace overview');
    });

    describe('purchase more storage button when namespace is using project enforcement', () => {
      it('does not render the button', () => {
        createComponent({
          provide: {
            isUsingNamespaceEnforcement: false,
            isUsingProjectEnforcementWithLimits: true,
          },
        });
        expect(findPurchaseButton().exists()).toBe(false);
      });
    });

    describe('purchase more storage button when namespace is NOT using project enforcement', () => {
      describe('when purchaseStorageUrl is provided', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              isUsingNamespaceEnforcement: true,
            },
          });
        });

        it('renders purchase button with the correct attributes', () => {
          expect(findPurchaseButton().attributes()).toMatchObject({
            href: 'some-fancy-url',
            target: '_blank',
          });
        });

        it('does not show modal on purchase button click', () => {
          findPurchaseButton().vm.$emit('click');

          expect(findLimitedAccessModal().exists()).toBe(false);
        });
      });

      describe('when purchaseStorageUrl is provided and limitedAccessModal FF is on', () => {
        beforeEach(async () => {
          gon.features = { limitedAccessModal: true };
          createComponent({
            provide: {
              isUsingNamespaceEnforcement: true,
            },
          });

          await waitForPromises();

          findPurchaseButton().vm.$emit('click');
          await nextTick();
        });

        it('shows modal', () => {
          expect(findLimitedAccessModal().isVisible()).toBe(true);
        });
      });

      it('is not rendered if purchaseStorageUrl is not provided', () => {
        createComponent({
          provide: {
            isUsingNamespaceEnforcement: true,
            purchaseStorageUrl: undefined,
          },
        });

        expect(findPurchaseButton().exists()).toBe(false);
      });
    });

    describe('enforcement type subtitle', () => {
      describe('enforcementType is project and there are limits set', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              isUsingNamespaceEnforcement: false,
              isUsingProjectEnforcementWithLimits: true,
            },
          });
        });

        it('renders project enforcement copy', () => {
          expect(wrapper.text()).toContain(
            'Projects under this namespace have 10.0 GiB of storage limit applied to repository and LFS objects. How are limits applied?',
          );
        });

        it('renders SaaS help link', () => {
          expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
            usageQuotasHelpPaths.usageQuotasProjectStorageLimit,
          );
        });

        it('renders SM help link if not in SaaS', () => {
          createComponent({
            provide: {
              isUsingNamespaceEnforcement: false,
              isUsingProjectEnforcementWithLimits: true,
              purchaseStorageUrl: null,
            },
          });

          expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
            usageQuotasHelpPaths.repositorySizeLimit,
          );
        });
      });

      describe('enforcementType is namespace', () => {
        // Namespace enforcement type is declared in ee/app/models/namespaces/storage/root_size.rb
        // More about namespace storage limit at https://docs.gitlab.com/ee/user/usage_quotas#namespace-storage-limit
        beforeEach(() => {
          createComponent();
        });

        it('renders namespace enforcement copy', () => {
          expect(wrapper.text()).toContain(
            'This namespace has 5.0 GiB of storage. How are limits applied?',
          );
        });

        it('renders namespace enforcement help link', () => {
          expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
            usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit,
          );
        });
      });
    });
  });

  describe('StorageStatisticsCard', () => {
    it('passes the correct props to StorageUsageOverviewCard', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithLimits: true,
        },
      });

      expect(findStorageUsageOverviewCard().props()).toEqual({
        usedStorage: namespace.rootStorageStatistics.storageSize,
        loading: false,
      });
    });

    it('passes the correct props to NamespaceLimitsStorageStatisticsCard', () => {
      createComponent();

      expect(findNamespaceLimitsStorageUsageOverviewCard().props()).toEqual({
        usedStorage: namespace.rootStorageStatistics.storageSize,
        purchasedStorage: namespace.additionalPurchasedStorageSize,
        loading: false,
      });
    });
  });

  describe('NamespaceLimitsTotalStorageAvailableBreakdownCard', () => {
    it('does not render when not in the namespace storage enforcement', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
        },
      });
      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().exists()).toBe(false);
    });

    it('does not render if there is no plan information', () => {
      createComponent({
        provide: {
          namespacePlanName: null,
        },
      });

      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().exists()).toBe(false);
    });

    it('renders when not in the namespace storage enforcement but IS in pre-enforcement', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isInNamespaceLimitsPreEnforcement: true,
        },
      });

      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().exists()).toBe(true);
    });

    it('passes correct props when the namespace is using namespace enforcement', () => {
      createComponent();

      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().props()).toEqual({
        purchasedStorage: namespace.additionalPurchasedStorageSize,
        loading: false,
      });
    });
  });

  describe('NoLimitsPurchasedStorageBreakdownCard', () => {
    it('does not render when namespace is using namespace enforcement', () => {
      createComponent();
      expect(findNoLimitsPurchasedStorageBreakdownCard().exists()).toBe(false);
    });

    it('does not render when namespace is using project enforcement with limits', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithLimits: true,
          perProjectStorageLimit: 1,
        },
      });
      expect(findNoLimitsPurchasedStorageBreakdownCard().exists()).toBe(false);
    });

    it('does not render when namespace IS using project enforcement with no limits but IS in pre-enforcement', () => {
      createComponent({
        provide: {
          isInNamespaceLimitsPreEnforcement: true,
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithNoLimits: true,
          perProjectStorageLimit: 0,
        },
      });

      expect(findNoLimitsPurchasedStorageBreakdownCard().exists()).toBe(false);
    });

    it('passes correct props when namespace IS using project enforcement with no limits', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithNoLimits: true,
          perProjectStorageLimit: 0,
        },
      });

      expect(findNoLimitsPurchasedStorageBreakdownCard().props()).toEqual({
        purchasedStorage: namespace.additionalPurchasedStorageSize,
        loading: false,
      });
    });
  });

  describe('ProjectLimitsExcessStorageBreakdownCard', () => {
    it('does not render when the namespace is NOT using project enforcement with limits', () => {
      createComponent();
      expect(findProjectLimitsExcessStorageBreakdownCard().exists()).toBe(false);
    });

    it('passes correct props when the namespace IS using project enforcement with limits', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithLimits: true,
        },
      });

      expect(findProjectLimitsExcessStorageBreakdownCard().props()).toEqual({
        purchasedStorage: namespace.additionalPurchasedStorageSize,
        limitedAccessModeEnabled: false,
        loading: false,
      });
    });

    it('does not render storage card if there is no plan information', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithLimits: true,
          namespacePlanName: null,
        },
      });

      expect(findProjectLimitsExcessStorageBreakdownCard().exists()).toBe(false);
    });
  });
});
