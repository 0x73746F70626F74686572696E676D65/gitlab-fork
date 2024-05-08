export const mockDoraMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { deploymentFrequency, changeFailureRate }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-dora-metrics-request',
            dora: {
              metrics: [
                {
                  date: null,
                  deployment_frequency: deploymentFrequency,
                  change_failure_rate: changeFailureRate,
                  __typename: 'DoraMetric',
                },
              ],
              __typename: 'Dora',
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockFlowMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { cycleTime, leadTime }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-flow-metrics-request',
            flowMetrics: {
              cycle_time: {
                unit: 'days',
                value: cycleTime,
                identifier: 'cycle_time',
                links: [],
                title: 'Cycle time',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              lead_time: {
                unit: 'days',
                value: leadTime,
                identifier: 'lead_time',
                links: [
                  {
                    label: 'Dashboard',
                    name: 'Lead time',
                    docsLink: null,
                    url: '/groups/test-graphql-dora/-/issues_analytics',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                  {
                    label: 'Go to docs',
                    name: 'Lead time',
                    docsLink: true,
                    url: '/help/user/analytics/index#definitions',
                    __typename: 'ValueStreamMetricLinkType',
                  },
                ],
                title: 'Lead time',
                __typename: 'ValueStreamAnalyticsMetric',
              },
              __typename: 'GroupValueStreamAnalyticsFlowMetrics',
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockVulnerabilityMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { criticalVulnerabilities }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-vulnerability-request',
            vulnerabilitiesCountByDay: {
              nodes: [
                {
                  date: null,
                  critical: criticalVulnerabilities,
                },
              ],
            },
          },
        },
      }),
    jest.fn(),
  );

export const mockAiMetricsResponse = (values = []) =>
  values.reduce(
    (acc, { codeContributorsCount, codeSuggestionsContributorsCount }) =>
      acc.mockResolvedValueOnce({
        data: {
          project: null,
          group: {
            id: 'fake-ai-metrics-request',
            aiMetrics: {
              codeContributorsCount,
              codeSuggestionsContributorsCount,
              __typename: 'AiMetrics',
            },
          },
        },
      }),
    jest.fn(),
  );
