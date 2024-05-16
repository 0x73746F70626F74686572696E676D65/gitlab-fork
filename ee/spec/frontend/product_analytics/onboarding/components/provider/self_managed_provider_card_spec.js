import { GlSprintf, GlLink } from '@gitlab/ui';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import SelfManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/self_managed_provider_card.vue';
import ProviderSettingsPreview from 'ee/product_analytics/onboarding/components/providers/provider_settings_preview.vue';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
  getProjectLevelAnalyticsProviderSettings,
} from '../../../mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

describe('SelfManagedProviderCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findProviderSettingsPreview = () => wrapper.findComponent(ProviderSettingsPreview);
  const findConnectSelfManagedProviderBtn = () =>
    wrapper.findByTestId('connect-your-own-provider-btn');
  const findUseInstanceConfigurationCheckbox = () =>
    wrapper.findByTestId('use-instance-configuration-checkbox');
  const findLink = () => wrapper.findComponent(GlLink);

  const mockConfirmAction = (confirmed) => confirmAction.mockResolvedValueOnce(confirmed);

  const createWrapper = (provide = {}) => {
    wrapper = shallowMountExtended(SelfManagedProviderCard, {
      propsData: {
        projectAnalyticsSettingsPath: '/settings/analytics',
      },
      provide: {
        projectLevelAnalyticsProviderSettings: getProjectLevelAnalyticsProviderSettings(),
        isInstanceConfiguredWithSelfManagedAnalyticsProvider: true,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const initProvider = () => {
    findConnectSelfManagedProviderBtn().vm.$emit('click');
    return waitForPromises();
  };

  const checkUseInstanceConfiguration = (checked) => {
    findUseInstanceConfigurationCheckbox().vm.$emit('input', checked);
  };

  const itShouldRedirectToSettings = (expectedConfirmationMessage) => {
    describe('when clicking setup', () => {
      it('should confirm with user that redirect to settings is required', async () => {
        mockConfirmAction(false);
        await initProvider();

        expect(confirmAction).toHaveBeenCalledWith(
          '',
          expect.objectContaining({
            primaryBtnText: 'Go to analytics settings',
            title: 'Connect your own provider',
            modalHtmlMessage: expect.stringContaining(expectedConfirmationMessage),
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
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render a title and description', () => {
      expect(wrapper.text()).toContain('Self-managed provider');
      expect(wrapper.text()).toContain(
        'Manage your own analytics provider to process, store, and query analytics data.',
      );
    });

    it('should show "Use instance-level settings" checkbox', () => {
      expect(findUseInstanceConfigurationCheckbox().exists()).toBe(true);
    });
  });

  describe('when instance config is a GitLab-managed provider', () => {
    it('should not show "Use instance-level settings" checkbox', () => {
      createWrapper({
        isInstanceConfiguredWithSelfManagedAnalyticsProvider: false,
      });

      expect(findUseInstanceConfigurationCheckbox().exists()).toBe(false);
    });
  });

  describe('"Use instance-level settings" checkbox default state', () => {
    it.each`
      defaultUseInstanceConfiguration | expectedCheckedState
      ${true}                         | ${'true'}
      ${false}                        | ${undefined}
    `(
      'when state is $defaultUseInstanceConfiguration',
      ({ defaultUseInstanceConfiguration, expectedCheckedState }) => {
        createWrapper({
          defaultUseInstanceConfiguration,
        });

        expect(findUseInstanceConfigurationCheckbox().attributes('checked')).toBe(
          expectedCheckedState,
        );
      },
    );
  });

  describe('when no project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectLevelAnalyticsProviderSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe('when "Use instance-level settings" is checked', () => {
      beforeEach(() => checkUseInstanceConfiguration(true));

      it('should inform user instance-settings will be used', () => {
        expect(wrapper.text()).toContain(
          'Your instance will be created on the provider configured in your instance settings.',
        );
      });

      it('does not render the link to the public helm-charts project', () => {
        expect(findLink().exists()).toBe(false);
      });

      describe('when selecting provider', () => {
        beforeEach(() => initProvider());

        it('should emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toHaveLength(1);
        });
      });
    });

    describe('when "Use instance-level settings" is unchecked', () => {
      beforeEach(() => checkUseInstanceConfiguration(false));

      it('renders the link to the public helm-charts project', () => {
        expect(findLink().attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/analytics-section/product-analytics/helm-charts',
        );
      });

      itShouldRedirectToSettings(`To connect your own provider, you'll be redirected`);
    });
  });

  describe('when some project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectLevelAnalyticsProviderSettings: getPartialProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe.each`
      scenario                                            | checked  | confirmMessage
      ${'when "Use instance-level settings" is checked'}  | ${true}  | ${'To connect to your instance-level provider, you must first remove project-level provider configuration'}
      ${'hen "Use instance-level settings" is unchecked'} | ${false} | ${"To connect your own provider, you'll be redirected"}
    `('$scenario', ({ checked, confirmMessage }) => {
      beforeEach(() => checkUseInstanceConfiguration(checked));

      it('should not show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().exists()).toBe(false);
      });

      itShouldRedirectToSettings(confirmMessage);
    });
  });

  describe('when all project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectLevelAnalyticsProviderSettings: getProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe('when "Use instance-level settings" is checked', () => {
      beforeEach(() => checkUseInstanceConfiguration(true));

      it('should not show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().exists()).toBe(false);
      });

      itShouldRedirectToSettings(
        `To connect to your instance-level provider, you must first remove project-level provider configuration.`,
      );
    });

    describe('when "Use instance-level settings" is unchecked', () => {
      beforeEach(() => checkUseInstanceConfiguration(false));

      it('should show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().props()).toMatchObject({
          configuratorConnectionString: 'https://configurator.example.com',
          collectorHost: 'https://collector.example.com',
          cubeApiBaseUrl: 'https://cubejs.example.com',
          cubeApiKey: 'abc-123',
        });
      });

      describe('when selecting provider', () => {
        beforeEach(() => initProvider());

        it('should emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toHaveLength(1);
          expect(wrapper.emitted('confirm').at(0)).toStrictEqual(['file-mock']);
        });
      });
    });
  });
});
