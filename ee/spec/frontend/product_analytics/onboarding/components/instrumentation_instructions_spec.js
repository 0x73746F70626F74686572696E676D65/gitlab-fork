import AnalyticsClipboardInput from 'ee/product_analytics/shared/analytics_clipboard_input.vue';
import InstrumentationInstructions from 'ee/product_analytics/onboarding/components/instrumentation_instructions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  HTML_SCRIPT_SETUP,
  IMPORT_NPM_PACKAGE,
  INIT_TRACKING,
  INSTALL_NPM_PACKAGE,
} from 'ee/product_analytics/onboarding/constants';
import {
  TEST_COLLECTOR_HOST,
  TEST_TRACKING_KEY,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('ProductAnalyticsSetupView', () => {
  let wrapper;

  const findKeyInputAt = (index) => wrapper.findAllComponents(AnalyticsClipboardInput).at(index);

  const findNpmInstructions = () => wrapper.findByTestId('npm-instrumentation-instructions');
  const findHtmlInstructions = () => wrapper.findByTestId('html-instrumentation-instructions');

  const createWrapper = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(InstrumentationInstructions, {
      propsData: {
        trackingKey: TEST_TRACKING_KEY,
        dashboardsPath: '/foo/bar/dashboards',
        ...props,
      },
      provide: {
        collectorHost: TEST_COLLECTOR_HOST,
        ...provide,
      },
    });
  };

  describe('when mounted', () => {
    it.each`
      key                    | index
      ${TEST_COLLECTOR_HOST} | ${0}
      ${TEST_TRACKING_KEY}   | ${1}
    `('should render key inputs at $index', ({ key, index }) => {
      createWrapper();

      expect(findKeyInputAt(index).props('value')).toBe(key);
    });

    it.each([true, false])(
      'renders the expected instructions when productAnalyticsSnowplowSupport feature flag is %s',
      ({ productAnalyticsSnowplowSupport }) => {
        createWrapper(
          {},
          {
            glFeatures: {
              productAnalyticsSnowplowSupport,
            },
          },
        );
        const installInstructionsWithKeys = wrapper.vm.replaceKeys(INSTALL_NPM_PACKAGE);
        const importInstructionsWithKeys = wrapper.vm.replaceKeys(IMPORT_NPM_PACKAGE);
        const initInstructionsWithKeys = wrapper.vm.replaceKeys(INIT_TRACKING);
        const htmlInstructionsWithKeys = wrapper.vm.replaceKeys(HTML_SCRIPT_SETUP);

        const npmInstructions = findNpmInstructions().text();
        const htmlInstructions = findHtmlInstructions().text();

        expect(npmInstructions).toContain(installInstructionsWithKeys);
        expect(npmInstructions).toContain(importInstructionsWithKeys);
        expect(npmInstructions).toContain(initInstructionsWithKeys);
        expect(htmlInstructions).toContain(htmlInstructionsWithKeys);
      },
    );
  });
});
