import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  AI_METRICS,
} from '~/analytics/shared/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import FlowMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/dora_metrics.query.graphql';
import VulnerabilitiesQuery from 'ee/analytics/dashboards/ai_impact/graphql/vulnerabilities.query.graphql';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import MetricTableCell from 'ee/analytics/dashboards/components/metric_table_cell.vue';
import TrendIndicator from 'ee/analytics/dashboards/components/trend_indicator.vue';
import { setLanguage } from 'jest/__helpers__/locale_helper';
import {
  mockDoraMetricsResponse,
  mockFlowMetricsResponse,
  mockVulnerabilityMetricsResponse,
  mockAiMetricsResponse,
} from '../helpers';
import { mockTableValues, mockTableLargeValues, mockAiMetricsValues } from '../mock_data';

const mockTypePolicy = {
  Query: { fields: { project: { merge: false }, group: { merge: false } } },
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
    aiMetricsRequest = mockAiMetricsResponse(mockAiMetricsValues),
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

  const createWrapper = ({ props = {}, apolloProvider = createMockApolloProvider() } = {}) => {
    wrapper = mountExtended(MetricTable, {
      apolloProvider,
      propsData: {
        namespace,
        isProject,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });

    return waitForPromises();
  };

  const createLargeValuesWrapper = ({
    props = {},
    apolloProvider = createMockApolloProviderLargeValues(),
  } = {}) => {
    wrapper = mountExtended(MetricTable, {
      apolloProvider,
      propsData: {
        namespace,
        isProject,
        ...props,
      },
    });

    return waitForPromises();
  };

  const findTableRow = (rowTestId) => wrapper.findByTestId(rowTestId);
  const findMetricTableCell = (rowTestId) => findTableRow(rowTestId).findComponent(MetricTableCell);
  const findValueTableCells = (rowTestId) =>
    findTableRow(rowTestId).findAll(`[data-testid="ai-impact-table-value-cell"]`);
  const findTrendIndicator = (rowTestId) => findTableRow(rowTestId).findComponent(TrendIndicator);
  const findSkeletonLoaders = (rowTestId) =>
    wrapper.findAll(`[data-testid="${rowTestId}"] [data-testid="metric-skeleton-loader"]`);

  describe.each`
    identifier                                | name                                    | testId                                            | change  | hasValueTooltips
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}      | ${'Deployment frequency'}               | ${'ai-impact-metric-deployment-frequency'}        | ${1}    | ${false}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}       | ${'Change failure rate'}                | ${'ai-impact-metric-change-failure-rate'}         | ${1}    | ${false}
    ${FLOW_METRICS.CYCLE_TIME}                | ${'Cycle time'}                         | ${'ai-impact-metric-cycle-time'}                  | ${-0.5} | ${false}
    ${FLOW_METRICS.LEAD_TIME}                 | ${'Lead time'}                          | ${'ai-impact-metric-lead-time'}                   | ${0}    | ${false}
    ${VULNERABILITY_METRICS.CRITICAL}         | ${'Critical vulnerabilities over time'} | ${'ai-impact-metric-vulnerability-critical'}      | ${-0.5} | ${false}
    ${AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE} | ${'Code Suggestions usage'}             | ${'ai-impact-metric-code-suggestions-usage-rate'} | ${1}    | ${true}
  `('for the $identifier table row', ({ identifier, name, testId, change, hasValueTooltips }) => {
    describe('when loading data', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders the metric name', () => {
        expect(findMetricTableCell(testId).props()).toEqual(
          expect.objectContaining({
            identifier,
            requestPath: namespace,
            isProject,
          }),
        );
      });

      it('renders a skeleton loader in each cell', () => {
        // Metric count + 1 for the trend indicator
        const loadingCellCount = Object.keys(mockTableValues[0]).length + 1;
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
        expect(wrapper.emitted('set-alerts')[0][0].errors).toHaveLength(1);
        expect(wrapper.emitted('set-alerts')[0][0].errors[0]).toContain(name);
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

      if (change === 0) {
        it('does not render the trend indicator', () => {
          expect(findTrendIndicator(testId).exists()).toBe(false);
        });
      } else {
        it('renders the trend indicator', () => {
          expect(findTrendIndicator(testId).props().change).toBe(change);
        });
      }

      if (hasValueTooltips) {
        it('adds tooltip to value cells', () => {
          const tooltip = getBinding(findValueTableCells(testId).at(0).element, 'gl-tooltip');

          expect(tooltip).toBeDefined();
        });

        it('adds hover classes to value cells', () => {
          expect(findValueTableCells(testId).at(0).classes()).toContain(
            'gl-cursor-pointer',
            'hover:gl-underline',
          );
        });
      } else {
        it('does not add tooltip to value cells', () => {
          const tooltip = getBinding(findValueTableCells(testId).at(0).element, 'gl-tooltip');

          expect(tooltip).toBeUndefined();
        });

        it('does not add hover classes to value cells', () => {
          expect(findValueTableCells(testId).at(0).classes()).not.toContain(
            'gl-cursor-pointer',
            'hover:gl-underline',
          );
        });
      }
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
        return createLargeValuesWrapper();
      });

      it('formats numbers correctly', () => {
        expect(findTableRow('ai-impact-metric-vulnerability-critical').html()).toContain(
          formattedValue,
        );
      });
    });
  });
});
