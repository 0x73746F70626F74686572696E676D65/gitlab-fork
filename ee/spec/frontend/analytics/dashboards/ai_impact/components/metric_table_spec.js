import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTooltip } from '@gitlab/ui';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  AI_METRICS,
} from '~/analytics/shared/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import FlowMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/dora_metrics.query.graphql';
import VulnerabilitiesQuery from 'ee/analytics/dashboards/ai_impact/graphql/vulnerabilities.query.graphql';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import MetricTableCell from 'ee/analytics/dashboards/components/metric_table_cell.vue';
import TrendIndicator from 'ee/analytics/dashboards/components/trend_indicator.vue';
import { setLanguage } from 'jest/__helpers__/locale_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  AI_IMPACT_TABLE_TRACKING_PROPERTY,
  EVENT_LABEL_CLICK_METRIC_IN_DASHBOARD_TABLE,
} from 'ee/analytics/analytics_dashboards/constants';
import {
  mockDoraMetricsResponse,
  mockFlowMetricsResponse,
  mockVulnerabilityMetricsResponse,
  mockAiMetricsResponse,
} from '../helpers';
import {
  mockTableValues,
  mockTableLargeValues,
  mockTableBlankValues,
  mockTableZeroValues,
} from '../mock_data';

const mockTypePolicy = {
  Query: { fields: { project: { merge: false }, group: { merge: false } } },
};
const mockGlAbilities = {
  readDora4Analytics: true,
  readCycleAnalytics: true,
  readSecurityResource: true,
};

Vue.use(VueApollo);

describe('Metric table', () => {
  let wrapper;

  const namespace = 'test-namespace';
  const isProject = false;

  const createMockApolloProvider = ({
    flowMetricsRequest = mockFlowMetricsResponse(mockTableValues),
    doraMetricsRequest = mockDoraMetricsResponse(mockTableValues),
    vulnerabilityMetricsRequest = mockVulnerabilityMetricsResponse(mockTableValues),
    aiMetricsRequest = mockAiMetricsResponse(mockTableValues),
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityMetricsRequest],
        [AiMetricsQuery, aiMetricsRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createMockApolloProviderLargeValues = ({
    flowMetricsRequest = mockFlowMetricsResponse(mockTableLargeValues),
    doraMetricsRequest = mockDoraMetricsResponse(mockTableLargeValues),
    vulnerabilityMetricsRequest = mockVulnerabilityMetricsResponse(mockTableLargeValues),
    aiMetricsRequest = mockAiMetricsResponse(mockTableLargeValues),
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityMetricsRequest],
        [AiMetricsQuery, aiMetricsRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createWrapper = ({
    props = {},
    glAbilities = {},
    apolloProvider = createMockApolloProvider(),
  } = {}) => {
    wrapper = mountExtended(MetricTable, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        namespace,
        isProject,
        ...props,
      },
      provide: {
        glAbilities: {
          ...mockGlAbilities,
          ...glAbilities,
        },
      },
    });

    return waitForPromises();
  };

  const deploymentFrequencyTestId = 'ai-impact-metric-deployment-frequency';
  const changeFailureRateTestId = 'ai-impact-metric-change-failure-rate';
  const cycleTimeTestId = 'ai-impact-metric-cycle-time';
  const leadTimeTestId = 'ai-impact-metric-lead-time';
  const vulnerabilityCriticalTestId = 'ai-impact-metric-vulnerability-critical';
  const codeSuggestionsUsageRateTestId = 'ai-impact-metric-code-suggestions-usage-rate';

  const findTableRow = (rowTestId) => wrapper.findByTestId(rowTestId);
  const findMetricTableCell = (rowTestId) => findTableRow(rowTestId).findComponent(MetricTableCell);
  const findValueTableCells = (rowTestId) =>
    findTableRow(rowTestId).findAll(`[data-testid="ai-impact-table-value-cell"]`);
  const findTrendIndicator = (rowTestId) => findTableRow(rowTestId).findComponent(TrendIndicator);
  const findSkeletonLoaders = (rowTestId) =>
    wrapper.findAll(`[data-testid="${rowTestId}"] [data-testid="metric-skeleton-loader"]`);
  const findMetricNoChangeLabel = (rowTestId) =>
    wrapper.find(`[data-testid="${rowTestId}"] [data-testid="metric-cell-no-change"]`);
  const findMetricNoChangeTooltip = (rowTestId) =>
    getBinding(findMetricNoChangeLabel(rowTestId).element, 'gl-tooltip');

  describe.each`
    identifier                                | testId                            | requestPath
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}      | ${deploymentFrequencyTestId}      | ${namespace}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}       | ${changeFailureRateTestId}        | ${namespace}
    ${FLOW_METRICS.CYCLE_TIME}                | ${cycleTimeTestId}                | ${namespace}
    ${FLOW_METRICS.LEAD_TIME}                 | ${leadTimeTestId}                 | ${namespace}
    ${VULNERABILITY_METRICS.CRITICAL}         | ${vulnerabilityCriticalTestId}    | ${namespace}
    ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE} | ${codeSuggestionsUsageRateTestId} | ${''}
  `('for the $identifier table row', ({ identifier, testId, requestPath }) => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the metric name', () => {
      expect(findMetricTableCell(testId).props()).toEqual(
        expect.objectContaining({ identifier, requestPath, isProject }),
      );
    });

    describe('metric drill-down clicked', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        findMetricTableCell(testId).vm.$emit('drill-down-clicked');
      });

      if (requestPath) {
        it(`should trigger tracking event`, () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).toHaveBeenCalledTimes(1);
          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_CLICK_METRIC_IN_DASHBOARD_TABLE,
            {
              label: identifier,
              property: AI_IMPACT_TABLE_TRACKING_PROPERTY,
            },
            undefined,
          );
        });
      } else {
        it('should not trigger tracking event', () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).not.toHaveBeenCalled();
        });
      }
    });
  });

  describe.each`
    identifier                                | name                                    | testId
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}      | ${'Deployment frequency'}               | ${deploymentFrequencyTestId}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}       | ${'Change failure rate'}                | ${changeFailureRateTestId}
    ${FLOW_METRICS.CYCLE_TIME}                | ${'Cycle time'}                         | ${cycleTimeTestId}
    ${FLOW_METRICS.LEAD_TIME}                 | ${'Lead time'}                          | ${leadTimeTestId}
    ${VULNERABILITY_METRICS.CRITICAL}         | ${'Critical vulnerabilities over time'} | ${vulnerabilityCriticalTestId}
    ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE} | ${'Code Suggestions usage'}             | ${codeSuggestionsUsageRateTestId}
  `('for the $identifier table row', ({ name, testId }) => {
    describe('when loading data', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders a skeleton loader in each cell', () => {
        // Metric count + 1 for the trend indicator
        const loadingCellCount = Object.keys(mockTableValues).length + 1;
        expect(findSkeletonLoaders(testId).length).toBe(loadingCellCount);
      });
    });

    describe('when the data fails to load', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            flowMetricsRequest: jest.fn().mockRejectedValue({}),
            doraMetricsRequest: jest.fn().mockRejectedValue({}),
            vulnerabilityMetricsRequest: jest.fn().mockRejectedValue({}),
            aiMetricsRequest: jest.fn().mockRejectedValue({}),
          }),
        });
      });

      it('emits `set-alerts` with the name of the failed metric', () => {
        expect(wrapper.emitted('set-alerts')).toHaveLength(1);
        expect(wrapper.emitted('set-alerts')[0][0].warnings[0]).toContain(name);
      });
    });

    describe('when the data is loaded', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('does not render the loading skeleton', () => {
        expect(findSkeletonLoaders(testId).length).toBe(0);
      });

      it('renders the metric values', () => {
        expect(findTableRow(testId).text()).toMatchSnapshot();
      });
    });
  });

  describe('change %', () => {
    describe('when there is no data', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableBlankValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(deploymentFrequencyTestId).text()).toBe('n/a');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(deploymentFrequencyTestId).value).toBe(
          'No data available',
        );
      });
    });

    describe('when there is blank data', () => {
      beforeEach(() => {
        return createWrapper({
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableZeroValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(deploymentFrequencyTestId).text()).toBe('0.0%');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(deploymentFrequencyTestId).value).toBe('No change');
      });
    });

    describe('when there is a change', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('does not invert the trend indicator for ascending metrics', () => {
        expect(findTrendIndicator(deploymentFrequencyTestId).props().change).toBe(1);
        expect(findTrendIndicator(deploymentFrequencyTestId).props().invertColor).toBe(false);
      });

      it('inverts the trend indicator for declining metrics', () => {
        expect(findTrendIndicator(changeFailureRateTestId).props().change).toBe(1);
        expect(findTrendIndicator(changeFailureRateTestId).props().invertColor).toBe(true);
      });
    });
  });

  describe('metric tooltips', () => {
    const hoverClasses = ['gl-cursor-pointer', 'hover:gl-underline'];

    beforeEach(() => {
      return createWrapper();
    });

    it('adds hover class and tooltip to code suggestions metric', () => {
      const metricCell = findValueTableCells(codeSuggestionsUsageRateTestId).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(true);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(true);
    });

    it('does not add hover class and tooltip to other metrics', () => {
      const metricCell = findValueTableCells(leadTimeTestId).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(false);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(false);
    });
  });

  describe('restricted metrics', () => {
    beforeEach(() => {
      return createWrapper({
        glAbilities: { readDora4Analytics: false },
      });
    });

    it.each([deploymentFrequencyTestId, changeFailureRateTestId])(
      'does not render the `%s` metric',
      (testId) => {
        expect(findTableRow(testId).exists()).toBe(false);
      },
    );

    it('emits `set-alerts` warning with the restricted metrics', () => {
      expect(wrapper.emitted('set-alerts').length).toBe(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: false,
        warnings: [],
        alerts: expect.arrayContaining([
          'You have insufficient permissions to view: Deployment frequency, Change failure rate',
        ]),
      });
    });
  });

  describe('i18n', () => {
    describe.each`
      language   | formattedValue
      ${'en-US'} | ${'5,000'}
      ${'de-DE'} | ${'5.000'}
    `('When the language is $language', ({ formattedValue, language }) => {
      beforeEach(() => {
        setLanguage(language);
        return createWrapper({ apolloProvider: createMockApolloProviderLargeValues() });
      });

      it('formats numbers correctly', () => {
        expect(findTableRow('ai-impact-metric-vulnerability-critical').html()).toContain(
          formattedValue,
        );
      });
    });
  });
});
