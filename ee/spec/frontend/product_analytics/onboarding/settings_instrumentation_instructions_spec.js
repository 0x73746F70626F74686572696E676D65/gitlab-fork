import { nextTick } from 'vue';
import { GlModal, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  TEST_COLLECTOR_HOST,
  TEST_TRACKING_KEY,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import SettingsInstrumentationInstructions from 'ee/product_analytics/onboarding/settings_instrumentation_instructions.vue';
import InstrumentationInstructions from 'ee/product_analytics/onboarding/components/instrumentation_instructions.vue';

import { stubComponent } from 'helpers/stub_component';

describe('ProductAnalyticsSettingsInstrumentationInstructions', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const dashboardsPath = '/foo/bar/dashboards';
  const onboardingPath = '/foo/bar/dashboards/onboarding';

  const findModal = () => wrapper.findComponent(GlModal);
  const findLink = () => wrapper.findComponent(GlLink);
  const findInstrumentationInstructionsButton = () =>
    wrapper.findByRole('button', {
      name: 'View instrumentation instructions',
    });
  const findInstrumentationInstructions = () => wrapper.findComponent(InstrumentationInstructions);

  const createWrapper = (props = {}) => {
    wrapper = mountExtended(SettingsInstrumentationInstructions, {
      provide: {
        collectorHost: TEST_COLLECTOR_HOST,
      },
      propsData: {
        dashboardsPath,
        onboardingPath,
        trackingKey: TEST_TRACKING_KEY,
        ...props,
      },
      stubs: {
        GlModal: stubComponent(GlModal),
      },
    });
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('has button to show instrumentation instructions', () => {
      expect(findInstrumentationInstructionsButton().exists()).toBe(true);
    });

    it('shows modal when clicking button', async () => {
      findInstrumentationInstructionsButton().trigger('click');
      await nextTick();

      expect(findModal().props('visible')).toBe(true);
    });

    it('hides modal when it is dismissed', async () => {
      const modal = findModal();

      findInstrumentationInstructionsButton().trigger('click');
      await nextTick();

      modal.vm.$emit('change', false);
      await nextTick();

      expect(findModal().props('visible')).toBe(false);
    });

    it('shows instrumentation instructions in modal', async () => {
      findInstrumentationInstructionsButton().trigger('click');
      await nextTick();

      expect(findInstrumentationInstructions().props()).toMatchObject({
        dashboardsPath,
        trackingKey: TEST_TRACKING_KEY,
      });
    });

    it('shows the link to the dashboards path', () => {
      expect(findLink().attributes('href')).toBe(dashboardsPath);
    });
  });
});
