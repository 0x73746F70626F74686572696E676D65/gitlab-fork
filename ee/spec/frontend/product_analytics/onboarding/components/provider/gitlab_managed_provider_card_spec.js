import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlModal, GlSprintf } from '@gitlab/ui';

import { PROMO_URL } from '~/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import GitlabManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/gitlab_managed_provider_card.vue';
import productAnalyticsProjectSettingsUpdate from 'ee/product_analytics/graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
  getProductAnalyticsProjectSettingsUpdateResponse,
  TEST_PROJECT_FULL_PATH,
} from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

describe('GitlabManagedProviderCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockMutate = jest.fn();

  const findContactSalesBtn = () => wrapper.findByTestId('contact-sales-team-btn');
  const findConnectGitLabProviderBtn = () =>
    wrapper.findByTestId('connect-gitlab-managed-provider-btn');
  const findRegionAgreementCheckbox = () => wrapper.findByTestId('region-agreement-checkbox');
  const findGcpZoneError = () => wrapper.findByTestId('gcp-zone-error');
  const findClearSettingsModal = () =>
    wrapper.findByTestId('clear-project-level-settings-confirmation-modal');
  const findModalError = () =>
    wrapper.findByTestId('clear-project-level-settings-confirmation-modal-error');

  const createWrapper = (provide = {}) => {
    wrapper = shallowMountExtended(GitlabManagedProviderCard, {
      apolloProvider: createMockApollo([[productAnalyticsProjectSettingsUpdate, mockMutate]]),
      provide: {
        projectLevelAnalyticsProviderSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        analyticsSettingsPath: `/${TEST_PROJECT_FULL_PATH}/-/settings/analytics`,
        managedClusterPurchased: true,
        namespaceFullPath: TEST_PROJECT_FULL_PATH,
        ...provide,
      },
      stubs: {
        GlSprintf,
        GlModal: stubComponent(GlModal),
      },
    });
  };

  const initProvider = () => {
    findRegionAgreementCheckbox().vm.$emit('input', true);
    findConnectGitLabProviderBtn().vm.$emit('click');
    return waitForPromises();
  };

  const confirmRemoveSetting = async () => {
    findClearSettingsModal().vm.$emit('primary');
    await nextTick();
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render a title and description', () => {
      expect(wrapper.text()).toContain('GitLab-managed provider');
      expect(wrapper.text()).toContain(
        'Use a GitLab-managed infrastructure to process, store, and query analytics events data.',
      );
    });
  });

  describe('when group does not have product analytics provider purchase', () => {
    beforeEach(() => createWrapper({ managedClusterPurchased: false }));

    it('does not show the GitLab-managed provider setup button', () => {
      expect(findConnectGitLabProviderBtn().exists()).toBe(false);
    });

    it('does not show the GCP zone confirmation checkbox', () => {
      expect(findRegionAgreementCheckbox().exists()).toBe(false);
    });

    it('shows a link to contact sales', () => {
      const btn = findContactSalesBtn();
      expect(btn.text()).toBe('Contact our sales team');
      expect(btn.attributes('href')).toBe(`${PROMO_URL}/sales/`);
    });
  });

  describe('when group has product analytics provider purchase', () => {
    describe('when some project provider settings are already configured', () => {
      beforeEach(() => {
        createWrapper({
          projectLevelAnalyticsProviderSettings: getPartialProjectLevelAnalyticsProviderSettings(),
        });
      });

      describe('when clicking setup', () => {
        it('should confirm with user that resetting settings is required', async () => {
          await initProvider();

          expect(findClearSettingsModal().props('visible')).toBe(true);
        });

        it('should not clear settings when user cancels', async () => {
          await initProvider();

          findClearSettingsModal().vm.$emit('cancelled');
          await nextTick();

          expect(mockMutate).not.toHaveBeenCalled();
        });

        describe('when the user confirms', () => {
          it('should set loading state', async () => {
            mockMutate.mockReturnValue(new Promise(() => {}));
            await initProvider();
            await confirmRemoveSetting();

            const modal = findClearSettingsModal();
            expect(modal.props('actionPrimary').attributes.loading).toBe(true);
            expect(modal.props('actionCancel').attributes.disabled).toBe(true);
          });

          it('should clear settings', async () => {
            mockMutate.mockResolvedValue(getProductAnalyticsProjectSettingsUpdateResponse());
            await initProvider();
            await confirmRemoveSetting();

            expect(mockMutate).toHaveBeenCalledWith({
              fullPath: 'group-1/project-1',
              productAnalyticsConfiguratorConnectionString: null,
              productAnalyticsDataCollectorHost: null,
              cubeApiBaseUrl: null,
              cubeApiKey: null,
            });
          });

          describe('when the mutation fails', () => {
            beforeEach(async () => {
              mockMutate.mockResolvedValue(
                getProductAnalyticsProjectSettingsUpdateResponse(
                  {
                    productAnalyticsConfiguratorConnectionString: null,
                    productAnalyticsDataCollectorHost: null,
                    cubeApiBaseUrl: null,
                    cubeApiKey: null,
                  },
                  [new Error('uh oh!')],
                ),
              );
              await initProvider();
              await confirmRemoveSetting();
              return waitForPromises();
            });

            it('should display an error when the mutation fails', () => {
              expect(findModalError().text()).toContain(
                'Failed to clear project-level settings. Please try again or clear them manually.',
              );
              expect(findModalError().findComponent(GlLink).attributes('href')).toBe(
                '/group-1/project-1/-/settings/analytics',
              );
            });

            it('should not show loading state', () => {
              const modal = findClearSettingsModal();

              expect(modal.props('actionPrimary').attributes.loading).toBe(false);
              expect(modal.props('actionCancel').attributes.disabled).toBe(false);
            });
          });

          describe('when the settings have successfully cleared', () => {
            beforeEach(async () => {
              mockMutate.mockResolvedValue(getProductAnalyticsProjectSettingsUpdateResponse());
              await initProvider();
              await confirmRemoveSetting();
              return waitForPromises();
            });

            it('should close the modal', () => {
              expect(findClearSettingsModal().props('visible')).toBe(false);
            });

            it('should emit "confirm" event', () => {
              expect(wrapper.emitted('confirm')).toHaveLength(1);
              expect(wrapper.emitted('confirm').at(0)).toStrictEqual(['file-mock']);
            });
          });
        });
      });
    });

    describe('when project has no existing settings configured', () => {
      beforeEach(() =>
        createWrapper({
          projectLevelAnalyticsProviderSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        }),
      );

      describe('when initialising without agreeing to region', () => {
        beforeEach(() => {
          findConnectGitLabProviderBtn().vm.$emit('click');
          return waitForPromises();
        });

        it('should show an error', () => {
          expect(findGcpZoneError().text()).toBe(
            'To continue, you must agree to event storage and processing in this region.',
          );
        });

        it('should not emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toBeUndefined();
        });

        describe('when agreeing to region', () => {
          beforeEach(() => {
            const checkbox = findRegionAgreementCheckbox();
            checkbox.vm.$emit('input', true);

            findConnectGitLabProviderBtn().vm.$emit('click');
            return waitForPromises();
          });

          it('should clear the error message', () => {
            expect(findGcpZoneError().exists()).toBe(false);
          });

          it('should emit "confirm" event', () => {
            expect(wrapper.emitted('confirm')).toHaveLength(1);
            expect(wrapper.emitted('confirm').at(0)).toStrictEqual(['file-mock']);
          });
        });
      });
    });
  });
});
