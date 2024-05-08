export const mockTimePeriods = [
  {
    key: '5-months-ago',
    label: 'Oct',
    start: new Date('2023-10-01T00:00:00.000Z'),
    end: new Date('2023-10-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 10,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '8.9',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 0,
      tooltip: '0/0',
    },
  },
  {
    key: '4-months-ago',
    label: 'Nov',
    start: new Date('2023-11-01T00:00:00.000Z'),
    end: new Date('2023-11-30T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 15,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '5.6',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 100,
      tooltip: '10/10',
    },
  },
  {
    key: '3-months-ago',
    label: 'Dec',
    start: new Date('2023-12-01T00:00:00.000Z'),
    end: new Date('2024-12-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: null,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '0.0',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 20,
      tooltip: '2/10',
    },
  },
  {
    key: '2-months-ago',
    label: 'Jan',
    start: new Date('2024-01-01T00:00:00.000Z'),
    end: new Date('2024-01-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: null,
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 90.9090909090909,
      tooltip: '10/11',
    },
  },
  {
    key: '1-months-ago',
    label: 'Feb',
    start: new Date('2024-02-01T00:00:00.000Z'),
    end: new Date('2024-02-29T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: '-',
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '7.5',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 50,
      tooltip: '5/10',
    },
  },
  {
    key: 'this-month',
    label: 'Mar',
    start: new Date('2024-03-01T00:00:00.000Z'),
    end: new Date('2024-03-15T13:00:00.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '4.0',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 88.88888888888889,
      tooltip: '8/9',
    },
  },
];

export const mockAiMetricsValues = [
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 20,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 10,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 4,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 20,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 10,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 4,
  },
];

export const mockTableValues = [
  {
    deploymentFrequency: 10,
    changeFailureRate: 0.1,
    cycleTime: 4,
    leadTime: 0,
    criticalVulnerabilities: 40,
    codeSuggestionsUsageRate: 5,
  },
  {
    deploymentFrequency: 20,
    changeFailureRate: 0.2,
    cycleTime: 2,
    leadTime: 2,
    criticalVulnerabilities: 20,
    codeSuggestionsUsageRate: 10,
  },
  {
    deploymentFrequency: 40,
    changeFailureRate: 0.4,
    cycleTime: 1,
    leadTime: 4,
    criticalVulnerabilities: 10,
    codeSuggestionsUsageRate: 25,
  },
  {
    deploymentFrequency: 10,
    changeFailureRate: 0.1,
    cycleTime: 4,
    leadTime: 1,
    criticalVulnerabilities: 40,
    codeSuggestionsUsageRate: 5,
  },
  {
    deploymentFrequency: 20,
    changeFailureRate: 0.2,
    cycleTime: 2,
    leadTime: 2,
    criticalVulnerabilities: 20,
    codeSuggestionsUsageRate: 10,
  },
  {
    deploymentFrequency: 40,
    changeFailureRate: 0.4,
    cycleTime: 1,
    leadTime: 4,
    criticalVulnerabilities: 10,
    codeSuggestionsUsageRate: 25,
  },
];

export const mockTableLargeValues = [
  {
    deploymentFrequency: 10000,
    changeFailureRate: 0.1,
    cycleTime: 4,
    leadTime: 0,
    criticalVulnerabilities: 4000,
    codeSuggestionsUsageRate: 500,
  },
  {
    deploymentFrequency: 20000,
    changeFailureRate: 0.2,
    cycleTime: 2,
    leadTime: 2,
    criticalVulnerabilities: 2000,
    codeSuggestionsUsageRate: 1000,
  },
  {
    deploymentFrequency: 40000,
    changeFailureRate: 0.4,
    cycleTime: 1,
    leadTime: 4,
    criticalVulnerabilities: 1000,
    codeSuggestionsUsageRate: 2500,
  },
  {
    deploymentFrequency: 10000,
    changeFailureRate: 0.1,
    cycleTime: 4,
    leadTime: 1,
    criticalVulnerabilities: 4000,
    codeSuggestionsUsageRate: 5000,
  },
  {
    deploymentFrequency: 20000,
    changeFailureRate: 0.2,
    cycleTime: 2,
    leadTime: 2,
    criticalVulnerabilities: 2000,
    codeSuggestionsUsageRate: 1000,
  },
  {
    deploymentFrequency: 40,
    changeFailureRate: 0.4,
    cycleTime: 1,
    leadTime: 4,
    criticalVulnerabilities: 5000,
    codeSuggestionsUsageRate: 2500,
  },
];
