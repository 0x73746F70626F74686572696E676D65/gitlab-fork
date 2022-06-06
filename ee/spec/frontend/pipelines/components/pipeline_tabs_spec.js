import { shallowMount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import BasePipelineTabs from '~/pipelines/components/pipeline_tabs.vue';
import PipelineTabs from 'ee/pipelines/components/pipeline_tabs.vue';
import CodequalityReportApp from 'ee/codequality_report/codequality_report.vue';
import CodequalityReportAppGraphql from 'ee/codequality_report/codequality_report_graphql.vue';
import LicenseComplianceApp from 'ee/license_compliance/components/app.vue';
import PipelineSecurityDashboard from 'ee/security_dashboard/components/pipeline/pipeline_security_dashboard.vue';

describe('The Pipeline Tabs', () => {
  let wrapper;

  const findCodeQualityTab = () => wrapper.findByTestId('code-quality-tab');
  const findDagTab = () => wrapper.findByTestId('dag-tab');
  const findFailedJobsTab = () => wrapper.findByTestId('failed-jobs-tab');
  const findJobsTab = () => wrapper.findByTestId('jobs-tab');
  const findLicenseTab = () => wrapper.findByTestId('license-tab');
  const findPipelineTab = () => wrapper.findByTestId('pipeline-tab');
  const findSecurityTab = () => wrapper.findByTestId('security-tab');
  const findTestsTab = () => wrapper.findByTestId('tests-tab');

  const findCodeQualityApp = () => wrapper.findComponent(CodequalityReportApp);
  const findCodeQualityAppGraphql = () => wrapper.findComponent(CodequalityReportAppGraphql);
  const findLicenseApp = () => wrapper.findComponent(LicenseComplianceApp);
  const findSecurityApp = () => wrapper.findComponent(PipelineSecurityDashboard);

  const defaultProvide = {
    canGenerateCodequalityReports: false,
    codequalityReportDownloadPath: '',
    defaultTabValue: '',
    exposeSecurityDashboard: false,
    exposeLicenseScanningData: false,
    failedJobsCount: 1,
    failedJobsSummary: [],
    totalJobCount: 10,
  };

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(PipelineTabs, {
        propsData,
        provide: {
          ...defaultProvide,
          ...provide,
        },
        stubs: {
          BasePipelineTabs,
          TestReports: { template: '<div id="tests" />' },
        },
      }),
    );
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('CE Tabs', () => {
    it.each`
      tabName          | tabComponent
      ${'Pipeline'}    | ${findPipelineTab}
      ${'Dag'}         | ${findDagTab}
      ${'Jobs'}        | ${findJobsTab}
      ${'Failed Jobs'} | ${findFailedJobsTab}
      ${'Tests'}       | ${findTestsTab}
    `('shows $tabName tab with its associated component', ({ tabComponent }) => {
      createComponent();

      expect(tabComponent().exists()).toBe(true);
    });

    describe('with no failed jobs', () => {
      beforeEach(() => {
        createComponent({
          provide: { failedJobsCount: 0 },
        });
      });

      it('hides the failed jobs tab', () => {
        expect(findFailedJobsTab().exists()).toBe(false);
      });
    });
  });

  describe('EE Tabs', () => {
    describe('visibility', () => {
      it.each`
        tabName       | tabComponent       | appComponent       | provideKey                     | isVisible | text
        ${'Security'} | ${findSecurityTab} | ${findSecurityApp} | ${'exposeSecurityDashboard'}   | ${true}   | ${'shows'}
        ${'Security'} | ${findSecurityTab} | ${findSecurityApp} | ${'exposeSecurityDashboard'}   | ${false}  | ${'hides'}
        ${'License'}  | ${findLicenseTab}  | ${findLicenseApp}  | ${'exposeLicenseScanningData'} | ${true}   | ${'shows'}
        ${'License'}  | ${findLicenseTab}  | ${findLicenseApp}  | ${'exposeLicenseScanningData'} | ${false}  | ${'hides'}
      `(
        '$text $tabName and its associated component when $provideKey is $provideKey ',
        ({ tabComponent, appComponent, provideKey, isVisible }) => {
          createComponent({
            provide: { [provideKey]: isVisible },
          });
          expect(tabComponent().exists()).toBe(isVisible);
          expect(appComponent().exists()).toBe(isVisible);
        },
      );
    });

    describe('code quality visibility', () => {
      describe('feature flags', () => {
        describe('with `graphqlCodeQualityFullReport` enabled', () => {
          beforeEach(() => {
            createComponent({
              provide: {
                canGenerateCodequalityReports: true,
                glFeatures: {
                  graphqlCodeQualityFullReport: true,
                },
              },
            });
          });

          it('shows the graphql code quality report app', () => {
            expect(findCodeQualityAppGraphql().exists()).toBe(true);
            expect(findCodeQualityApp().exists()).toBe(false);
          });
        });

        describe('with `graphqlCodeQualityFullReport` disabled', () => {
          beforeEach(() => {
            createComponent({
              provide: {
                canGenerateCodequalityReports: true,
                glFeatures: {
                  graphqlCodeQualityFullReport: false,
                },
              },
            });
          });

          it('shows the default code quality report app', () => {
            expect(findCodeQualityAppGraphql().exists()).toBe(false);
            expect(findCodeQualityApp().exists()).toBe(true);
          });
        });
      });

      it.each`
        provideValue | isVisible | codequalityReportDownloadPath | text
        ${true}      | ${true}   | ${''}                         | ${'shows'}
        ${false}     | ${false}  | ${''}                         | ${'hides'}
        ${false}     | ${true}   | ${'/path'}                    | ${'shows'}
        ${true}      | ${true}   | ${'/path'}                    | ${'shows'}
      `(
        '$text Code Quality and its associated component when canGenerateCodequalityReports is $provideValue and codequalityReportDownloadPath is $codequalityReportDownloadPath',
        ({ provideValue, isVisible, codequalityReportDownloadPath }) => {
          createComponent({
            provide: { canGenerateCodequalityReports: provideValue, codequalityReportDownloadPath },
          });
          expect(findCodeQualityTab().exists()).toBe(isVisible);
          expect(findCodeQualityApp().exists()).toBe(isVisible);
        },
      );
    });
  });
});
