import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import App from 'ee/vue_merge_request_widget/components/widget/app.vue';
import MrSecurityWidgetEE from 'ee/vue_merge_request_widget/extensions/security_reports/mr_widget_security_reports.vue';
import MrSecurityWidgetCE from '~/vue_merge_request_widget/extensions/security_reports/mr_widget_security_reports.vue';
import MrTestReportWidget from '~/vue_merge_request_widget/extensions/test_report/index.vue';
import MrMetricsWidget from 'ee/vue_merge_request_widget/extensions/metrics/index.vue';
import MrCodeQualityWidget from '~/vue_merge_request_widget/extensions/code_quality/index.vue';
import MrTerraformWidget from '~/vue_merge_request_widget/extensions/terraform/index.vue';
import MrStatusChecksWidget from 'ee/vue_merge_request_widget/extensions/status_checks/index.vue';
import MrBrowserPerformanceWidget from 'ee/vue_merge_request_widget/extensions/browser_performance/index.vue';
import MrLoadPerformanceWidget from 'ee/vue_merge_request_widget/extensions/load_performance/index.vue';
import MrLicenseComplianceWidget from 'ee/vue_merge_request_widget/extensions/license_compliance/index.vue';

describe('MR Widget App', () => {
  let wrapper;
  let mock;

  const createComponent = ({ mr = {} } = {}) => {
    wrapper = shallowMountExtended(App, {
      propsData: {
        mr: {
          securityConfigurationPath: '/help/user/application_security/index.md',
          sourceProjectFullPath: 'namespace/project',
          pipeline: {
            path: '/path/to/pipeline',
          },
          ...mr,
        },
      },
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('MRSecurityWidget', () => {
    it('mounts MrSecurityWidgetEE when user has necessary permissions', async () => {
      createComponent({ mr: { canReadVulnerabilities: true } });

      await waitForPromises();

      expect(wrapper.findComponent(MrSecurityWidgetEE).exists()).toBe(true);
    });

    it('mounts MrSecurityWidgetCE when user does not have necessary permissions', async () => {
      createComponent({ mr: { canReadVulnerabilities: false } });

      await waitForPromises();

      expect(wrapper.findComponent(MrSecurityWidgetCE).exists()).toBe(true);
    });
  });

  describe('License Compliance Widget', () => {
    it('is mounted when the report is enabled and endpoint is provided', async () => {
      createComponent({
        mr: {
          enabledReports: { licenseScanning: true },
          licenseCompliance: { license_scanning: { full_report_path: 'full/report/path' } },
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(MrLicenseComplianceWidget).exists()).toBe(true);
    });

    it('is not mounted when the report is not enabled', async () => {
      createComponent({ mr: { enabledReports: {} } });

      await waitForPromises();

      expect(wrapper.findComponent(MrLicenseComplianceWidget).exists()).toBe(false);
    });
  });

  describe.each`
    widgetName                    | widget                        | endpoint
    ${'testReportWidget'}         | ${MrTestReportWidget}         | ${'testResultsPath'}
    ${'metricsWidget'}            | ${MrMetricsWidget}            | ${'metricsReportsPath'}
    ${'codeQualityWidget'}        | ${MrCodeQualityWidget}        | ${'codequalityReportsPath'}
    ${'terraformPlansWidget'}     | ${MrTerraformWidget}          | ${'terraformReportsPath'}
    ${'statusChecksWidget'}       | ${MrStatusChecksWidget}       | ${'apiStatusChecksPath'}
    ${'browserPerformanceWidget'} | ${MrBrowserPerformanceWidget} | ${'browserPerformance'}
    ${'loadPerformanceWidget'}    | ${MrLoadPerformanceWidget}    | ${'loadPerformance'}
  `('$widgetName', ({ widget, endpoint }) => {
    beforeEach(() => {
      mock.onGet(endpoint).reply(HTTP_STATUS_OK);
    });

    it(`is mounted when ${endpoint} is defined`, async () => {
      createComponent({ mr: { [endpoint]: `path/to/${endpoint}` } });

      await waitForPromises();
      jest.advanceTimersByTime(1);

      expect(wrapper.findComponent(widget).exists()).toBe(true);
    });

    it(`is not mounted when ${endpoint} is not defined`, async () => {
      createComponent();

      await waitForPromises();
      jest.advanceTimersByTime(1);

      expect(wrapper.findComponent(widget).exists()).toBe(false);
    });
  });
});
