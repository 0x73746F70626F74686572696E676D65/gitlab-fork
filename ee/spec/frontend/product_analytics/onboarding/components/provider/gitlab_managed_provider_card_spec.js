import { GlSprintf } from '@gitlab/ui';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { PROMO_URL } from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import GitlabManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/gitlab_managed_provider_card.vue';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
} from '../../../mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

describe('GitlabManagedProviderCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockConfirmAction = (confirmed) => confirmAction.mockResolvedValueOnce(confirmed);

  const findContactSalesBtn = () => wrapper.findByTestId('contact-sales-team-btn');
  const findConnectGitLabProviderBtn = () =>
    wrapper.findByTestId('connect-gitlab-managed-provider-btn');
  const findRegionAgreementCheckbox = () => wrapper.findByTestId('region-agreement-checkbox');
  const findGcpZoneError = () => wrapper.findByTestId('gcp-zone-error');

  const createWrapper = (provide = {}) => {
    wrapper = shallowMountExtended(GitlabManagedProviderCard, {
      propsData: {
        projectAnalyticsSettingsPath: '/settings/analytics',
      },
      provide: {
        projectLevelAnalyticsProviderSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        managedClusterPurchased: true,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const initProvider = () => {
    findRegionAgreementCheckbox().vm.$emit('input', true);
    findConnectGitLabProviderBtn().vm.$emit('click');
    return waitForPromises();
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
        it('should confirm with user that redirect to settings is required', async () => {
          mockConfirmAction(false);
          await initProvider();

          expect(confirmAction).toHaveBeenCalledWith(
            '',
            expect.objectContaining({
              primaryBtnText: 'Go to analytics settings',
              title: 'Reset existing project provider settings',
              modalHtmlMessage: expect.stringContaining(
                `This project uses the provider configuration. To connect to a GitLab-managed provider, you'll be redirected`,
              ),
            }),
          );
        });

        it('should not emit "open-settings" event when user cancels', async () => {
          mockConfirmAction(false);
          await initProvider();

          expect(wrapper.emitted('open-settings')).toBeUndefined();
        });

        it('should emit "open-settings" event when confirmed', async () => {
          mockConfirmAction(true);
          await initProvider();

          expect(wrapper.emitted('open-settings')).toHaveLength(1);
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
