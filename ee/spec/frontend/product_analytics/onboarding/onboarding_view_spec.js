import { nextTick } from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
import ProductAnalyticsOnboardingView from 'ee/product_analytics/onboarding/onboarding_view.vue';
import ProductAnalyticsOnboardingSetup from 'ee/product_analytics/onboarding/onboarding_setup.vue';
import ProductAnalyticsOnboardingState from 'ee/product_analytics/onboarding/components/onboarding_state.vue';
import ProviderSelectionView from 'ee/product_analytics/onboarding/components/providers/provider_selection_view.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { TEST_HOST } from 'spec/test_constants';
import { createAlert } from '~/alert';
import {
  STATE_LOADING_INSTANCE,
  STATE_CREATE_INSTANCE,
  STATE_WAITING_FOR_EVENTS,
} from 'ee/product_analytics/onboarding/constants';
import {
  TEST_TRACKING_KEY,
  TEST_COLLECTOR_HOST,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import { TEST_PROJECT_FULL_PATH } from '../mock_data';

jest.mock('~/alert');

describe('ProductAnalyticsOnboardingView', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const $router = {
    push: jest.fn(),
  };

  const errorMessage = 'some error';

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findProviderSelection = () => wrapper.findComponent(ProviderSelectionView);
  const findSetupView = () => wrapper.findComponent(ProductAnalyticsOnboardingSetup);
  const findStateComponent = () => wrapper.findComponent(ProductAnalyticsOnboardingState);

  const createWrapper = (provide = {}) => {
    wrapper = shallowMountExtended(ProductAnalyticsOnboardingView, {
      provide: {
        namespaceFullPath: TEST_PROJECT_FULL_PATH,
        chartEmptyStateIllustrationPath: TEST_HOST,
        collectorHost: TEST_COLLECTOR_HOST,
        trackingKey: TEST_TRACKING_KEY,
        dashboardsPath: '/analytics/dashboards',
        canSelectGitlabManagedProvider: false,
        ...provide,
      },
      mocks: {
        $router,
      },
    });
  };

  const emitStateChange = async (state) => {
    await findStateComponent().vm.$emit('change', state);
    await nextTick();
  };

  const expectAlertOnError = async ({ finder, captureError, message }) => {
    const error = new Error(errorMessage);

    finder().vm.$emit('error', error);

    await nextTick();

    expect(createAlert).toHaveBeenCalledWith({
      message,
      captureError,
      error,
    });
  };

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not show the provider selection view', () => {
      expect(findProviderSelection().exists()).toBe(false);
    });

    it('does not show the setup view', () => {
      expect(findSetupView().exists()).toBe(false);
    });

    it('creates an onboarding state component', () => {
      expect(findStateComponent().props()).toMatchObject({
        state: '',
        pollState: false,
      });
    });
  });

  describe('create and loading instance', () => {
    beforeEach(() => {
      createWrapper({
        canSelectGitlabManagedProvider: true,
      });
    });

    it.each([STATE_CREATE_INSTANCE, STATE_LOADING_INSTANCE])(
      'renders provider_selection when the state is "%s"',
      async (state) => {
        await emitStateChange(state);

        expect(findProviderSelection().props('loadingInstance')).toBe(
          state === STATE_LOADING_INSTANCE,
        );
      },
    );
  });

  describe('when waiting for events', () => {
    beforeEach(() => {
      createWrapper();
      return emitStateChange(STATE_WAITING_FOR_EVENTS);
    });

    it('renders the setup view', () => {
      expect(findSetupView().props('isInitialSetup')).toBe(true);
    });
  });

  describe('provider selection component events', () => {
    beforeEach(() => {
      createWrapper({
        canSelectGitlabManagedProvider: true,
      });
      return emitStateChange(STATE_CREATE_INSTANCE);
    });

    it(`activates polling on initialized`, async () => {
      findProviderSelection().vm.$emit('initialized');

      await nextTick();

      expect(findStateComponent().props('pollState')).toBe(true);
    });

    it('creates an alert on error with the error message', () => {
      expectAlertOnError({
        finder: findProviderSelection,
        captureError: true,
        message: errorMessage,
      });
    });
  });

  describe('state component events', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('routes to "index" on complete', async () => {
      findStateComponent().vm.$emit('complete');

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: 'index' });
    });

    it('creates an alert on error with a fixed message', () => {
      expectAlertOnError({
        finder: findStateComponent,
        captureError: false,
        message: 'An error occurred while fetching data. Refresh the page to try again.',
      });
    });
  });
});
