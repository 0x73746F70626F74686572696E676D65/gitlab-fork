import { GlBadge } from '@gitlab/ui';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import MRSecurityWidget from 'ee/vue_merge_request_widget/extensions/security_reports/mr_widget_security_reports.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import SummaryText from 'ee/vue_merge_request_widget/extensions/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import api from '~/api';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({ render: () => {} }));

describe('MR Widget Security Reports', () => {
  let wrapper;
  let mockAxios;

  const securityConfigurationPath = '/help/user/application_security/index.md';
  const sourceProjectFullPath = 'namespace/project';

  const sastHelp = '/help/user/application_security/sast/index';
  const dastHelp = '/help/user/application_security/dast/index';
  const coverageFuzzingHelp = '/help/user/application_security/coverage-fuzzing/index';
  const secretDetectionHelp = '/help/user/application_security/secret-detection/index';
  const apiFuzzingHelp = '/help/user/application_security/api-fuzzing/index';
  const dependencyScanningHelp = '/help/user/application_security/api-fuzzing/index';
  const containerScanningHelp = '/help/user/application_security/container-scanning/index';

  const reportEndpoints = {
    sastComparisonPathV2: '/my/sast/endpoint',
    dastComparisonPathV2: '/my/dast/endpoint',
    dependencyScanningComparisonPathV2: '/my/dependency-scanning/endpoint',
    coverageFuzzingComparisonPathV2: '/my/coverage-fuzzing/endpoint',
    apiFuzzingComparisonPathV2: '/my/api-fuzzing/endpoint',
    secretDetectionComparisonPathV2: '/my/secret-detection/endpoint',
    containerScanningComparisonPathV2: '/my/container-scanning/endpoint',
  };

  const createComponent = ({ propsData, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(MRSecurityWidget, {
      propsData: {
        ...propsData,
        mr: {
          targetProjectFullPath: '',
          pipeline: {
            path: '/path/to/pipeline',
          },
          enabledReports: {
            sast: true,
            dast: true,
            dependencyScanning: true,
            containerScanning: true,
            coverageFuzzing: true,
            apiFuzzing: true,
            secretDetection: true,
          },
          ...propsData?.mr,
          ...reportEndpoints,
          securityConfigurationPath,
          sourceProjectFullPath,
          sastHelp,
          dastHelp,
          containerScanningHelp,
          dependencyScanningHelp,
          coverageFuzzingHelp,
          secretDetectionHelp,
          apiFuzzingHelp,
        },
      },
      stubs: {
        MrWidgetRow,
        VulnerabilityFindingModal: stubComponent(VulnerabilityFindingModal),
      },
    });
  };

  const createComponentAndExpandWidget = async ({ mockDataFn, mockDataProps, mrProps = {} }) => {
    mockDataFn(mockDataProps);
    createComponent({
      mountFn: mountExtended,
      propsData: {
        mr: mrProps,
      },
    });

    await waitForPromises();

    // Click on the toggle button to expand data
    wrapper.findByRole('button', { name: 'Show details' }).trigger('click');
    await nextTick();

    // Second next tick is for the dynamic scroller
    await nextTick();
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findWidgetRow = (reportType) => wrapper.findByTestId(`report-${reportType}`);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findReportSummaryText = (at) => wrapper.findAllComponents(SummaryText).at(at);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findComponent(GlBadge);
  const findStandaloneModal = () => wrapper.findByTestId('vulnerability-finding-modal');
  const findDynamicScroller = () => wrapper.findByTestId('dynamic-content-scroller');

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('with active pipeline', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: true } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with no enabled reports', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: false, enabledReports: {} } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with empty MR data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should mount the widget component', () => {
      expect(findWidget().props()).toMatchObject({
        statusIconName: 'success',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: expect.any(Function),
        multiPolling: true,
      });
    });

    it('handles loading state', async () => {
      expect(findSummaryText().props()).toMatchObject({ isLoading: true });
      findWidget().vm.$emit('is-loading', false);
      await nextTick();
      expect(findSummaryText().props()).toMatchObject({ isLoading: false });
    });

    it('does not display the summary highlights component', () => {
      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('should not be collapsible', () => {
      expect(findWidget().props('isCollapsible')).toBe(false);
    });
  });

  describe('with MR data', () => {
    const mockWithData = ({ findings } = {}) => {
      mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(
        HTTP_STATUS_OK,
        findings?.sast || {
          added: [
            {
              uuid: '1',
              severity: 'critical',
              name: 'Password leak',
              state: 'dismissed',
            },
            { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
          ],
          fixed: [
            { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
            { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
          ],
        },
      );

      mockAxios.onGet(reportEndpoints.dastComparisonPathV2).replyOnce(
        HTTP_STATUS_OK,
        findings?.dast || {
          added: [
            { uuid: '5', severity: 'low', name: 'SQL Injection' },
            { uuid: '3', severity: 'unknown', name: 'Weak password' },
          ],
        },
      );

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    const createComponentWithData = async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
      });

      await waitForPromises();
    };

    it('should make a call only for enabled reports', async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
        propsData: {
          mr: {
            enabledReports: {
              sast: true,
              dast: true,
            },
          },
        },
      });

      await waitForPromises();

      expect(mockAxios.history.get).toHaveLength(2);
    });

    it('should display the view all pipeline findings button', async () => {
      await createComponent();

      expect(findWidget().props('actionButtons')).toEqual([
        {
          href: '/path/to/pipeline/security',
          text: 'View all pipeline findings',
          trackFullReportClicked: true,
        },
      ]);
    });

    it('should display the dismissed badge', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });
      expect(findDismissedBadge().text()).toBe('Dismissed');
    });

    it('should mount the widget component', async () => {
      await createComponentWithData();

      expect(findWidget().props()).toMatchObject({
        statusIconName: 'warning',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: wrapper.vm.fetchCollapsedData,
        multiPolling: true,
      });
    });

    it('computes the total number of new potential vulnerabilities correctly', async () => {
      await createComponentWithData();

      expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
      expect(findSummaryHighlights().props()).toMatchObject({
        highlights: { critical: 1, high: 1, other: 2 },
      });
    });

    it('tells the widget to be collapsible only if there is data', async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
      });

      expect(findWidget().props('isCollapsible')).toBe(false);
      await waitForPromises();
      expect(findWidget().props('isCollapsible')).toBe(true);
    });

    it('displays detailed data when expanded', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(wrapper.findByText(/Weak password/).exists()).toBe(true);
      expect(wrapper.findByText(/Password leak/).exists()).toBe(true);
      expect(wrapper.findByTestId('sast-scan-report').text()).toBe(
        'SAST detected 2 new potential vulnerabilities',
      );
    });

    it('contains new and fixed findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(findDynamicScroller().props('items')).toEqual([
        // New findings
        {
          uuid: '1',
          severity: 'critical',
          name: 'Password leak',
          state: 'dismissed',
        },
        { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
        // Fixed findings
        { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
        { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
      expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
    });

    it('contains only fixed findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              fixed: [
                { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
                { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
              ],
            },
            dast: {},
          },
        },
      });

      expect(findDynamicScroller().props('items')).toEqual([
        { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
        { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').exists()).toBe(false);
      expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
    });

    it('contains only added findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {},
          },
        },
      });

      expect(findDynamicScroller().props('items')).toEqual([
        { uuid: '5', severity: 'low', name: 'SQL Injection' },
        { uuid: '3', severity: 'unknown', name: 'Weak password' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
      expect(wrapper.findByTestId('fixed-findings-title').exists()).toBe(false);
    });

    it('tells summary-text to display a ui hint when there are 25 findings in a single report', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(25)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });

    it('tells summary-text NOT to display a ui hint when there are less 25 findings', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(24)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(false);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });
  });

  describe('error states', () => {
    const mockWithData = ({ errorCode = HTTP_STATUS_INTERNAL_SERVER_ERROR } = {}) => {
      mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(errorCode);

      mockAxios.onGet(reportEndpoints.dastComparisonPathV2).replyOnce(HTTP_STATUS_OK, {
        added: [
          { uuid: 5, severity: 'low', name: 'SQL Injection' },
          { uuid: 3, severity: 'unknown', name: 'Weak password' },
        ],
      });

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    it('displays an error message for the individual level report', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(true);
    });

    it('displays a top level error message when there is a bad request', async () => {
      mockWithData({ errorCode: HTTP_STATUS_BAD_REQUEST });
      createComponent({ mountFn: mountExtended });

      await waitForPromises();

      expect(
        wrapper
          .findByText('Parsing schema failed. Check the validity of your .gitlab-ci.yml content.')
          .exists(),
      ).toBe(true);

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(false);
    });
  });

  describe('help popovers', () => {
    const mockWithData = () => {
      Object.keys(reportEndpoints).forEach((key, i) => {
        mockAxios.onGet(reportEndpoints[key]).replyOnce(HTTP_STATUS_OK, {
          added: [{ uuid: i, severity: 'critical', name: 'Password leak' }],
        });
      });
    };

    it.each`
      reportType               | reportTitle                                      | helpPath
      ${'SAST'}                | ${'Static Application Security Testing (SAST)'}  | ${sastHelp}
      ${'DAST'}                | ${'Dynamic Application Security Testing (DAST)'} | ${dastHelp}
      ${'DEPENDENCY_SCANNING'} | ${'Dependency scanning'}                         | ${dependencyScanningHelp}
      ${'COVERAGE_FUZZING'}    | ${'Coverage fuzzing'}                            | ${coverageFuzzingHelp}
      ${'API_FUZZING'}         | ${'API fuzzing'}                                 | ${apiFuzzingHelp}
      ${'SECRET_DETECTION'}    | ${'Secret detection'}                            | ${secretDetectionHelp}
      ${'CONTAINER_SCANNING'}  | ${'Container scanning'}                          | ${containerScanningHelp}
    `(
      'shows the correct help popover for $reportType',
      async ({ reportType, reportTitle, helpPath }) => {
        await createComponentAndExpandWidget({ mockDataFn: mockWithData });

        expect(findWidgetRow(reportType).props('helpPopover')).toMatchObject({
          options: { title: reportTitle },
          content: { learnMorePath: helpPath },
        });
      },
    );
  });

  describe('modal', () => {
    const mockWithData = (props) => {
      Object.keys(reportEndpoints).forEach((key, i) => {
        mockAxios.onGet(reportEndpoints[key]).replyOnce(HTTP_STATUS_OK, {
          added: [
            {
              uuid: i.toString(),
              severity: 'critical',
              name: 'Password leak',
              found_by_pipeline: {
                iid: 1,
              },
              project: {
                id: 278964,
                name: 'GitLab',
                full_path: '/gitlab-org/gitlab',
                full_name: 'GitLab.org / GitLab',
              },
              ...props,
            },
          ],
        });
      });
    };

    const createComponentExpandWidgetAndOpenModal = async ({
      mockDataFn = mockWithData,
      mockDataProps,
      mrProps,
    } = {}) => {
      await createComponentAndExpandWidget({
        mockDataFn,
        mockDataProps,
        mrProps,
      });

      // Click on the vulnerability name
      wrapper.findAllByText('Password leak').at(0).trigger('click');
    };

    const mockWithDataOneFinding = (state = 'dismissed') => {
      mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(HTTP_STATUS_OK, {
        added: [
          {
            uuid: '1',
            severity: 'critical',
            name: 'Password leak',
            state,
            found_by_pipeline: {
              iid: 1,
            },
            project: {
              id: 278964,
              name: 'GitLab',
              full_path: '/gitlab-org/gitlab',
              full_name: 'GitLab.org / GitLab',
            },
          },
        ],
        fixed: [],
      });

      [
        reportEndpoints.dastComparisonPathV2,
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    it('does not display the modal until the finding is clicked', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
      });

      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('clears modal data when the modal is closed', async () => {
      await createComponentExpandWidgetAndOpenModal();

      expect(findStandaloneModal().props('modal')).not.toBe(null);

      findStandaloneModal().vm.$emit('hidden');
      await nextTick();

      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('renders the modal when the finding is clicked', async () => {
      const targetProjectFullPath = 'root/security-reports-v2';
      await createComponentExpandWidgetAndOpenModal({
        mrProps: { targetProjectFullPath },
      });

      const modal = findStandaloneModal();

      expect(modal.props()).toMatchObject({
        findingUuid: '0',
        pipelineIid: 1,
        projectFullPath: targetProjectFullPath,
      });
    });

    it('renders the dismissed badge when `dismissed` is emitted', async () => {
      await createComponentExpandWidgetAndOpenModal({
        mockDataFn: mockWithDataOneFinding,
        mockDataProps: { state: 'detected' },
      });

      expect(findDismissedBadge().exists()).toBe(false);

      findStandaloneModal().vm.$emit('dismissed');
      await nextTick();

      expect(findDismissedBadge().exists()).toBe(true);
    });

    it('does not render the dismissed badge when `detected` is emitted', async () => {
      await createComponentExpandWidgetAndOpenModal({ mockDataFn: mockWithDataOneFinding });

      expect(findDismissedBadge().exists()).toBe(true);

      findStandaloneModal().vm.$emit('detected');
      await nextTick();

      expect(findDismissedBadge().exists()).toBe(false);
    });
  });
});
