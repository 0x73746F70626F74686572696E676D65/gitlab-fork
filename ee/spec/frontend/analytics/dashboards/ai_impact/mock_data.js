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

const mockTableRow = (
  deploymentFrequency,
  changeFailureRate,
  cycleTime,
  leadTime,
  criticalVulnerabilities,
  [codeSuggestionsContributorsCount, codeContributorsCount],
) => ({
  deploymentFrequency,
  changeFailureRate,
  cycleTime,
  leadTime,
  criticalVulnerabilities,
  codeSuggestionsContributorsCount,
  codeContributorsCount,
});

export const mockTableValues = [
  mockTableRow(10, 0.2, 1, 1, 40, [1, 20]),
  mockTableRow(20, 0.4, 2, 2, 20, [1, 10]),
  mockTableRow(40, 0.6, 4, 4, 10, [1, 4]),
  mockTableRow(10, 0.2, 1, 1, 40, [1, 20]),
  mockTableRow(20, 0.4, 2, 2, 20, [1, 10]),
  mockTableRow(40, 0.6, 4, 4, 10, [1, 4]),
];

export const mockTableLargeValues = [
  mockTableRow(10000, 0.1, 4, 0, 4000, [500, 1000]),
  mockTableRow(20000, 0.2, 2, 2, 2000, [1000, 2000]),
  mockTableRow(40000, 0.4, 1, 4, 1000, [2500, 5000]),
  mockTableRow(10000, 0.1, 4, 1, 4000, [5000, 10000]),
  mockTableRow(20000, 0.2, 2, 2, 2000, [1000, 2000]),
  mockTableRow(40, 0.4, 1, 4, 5000, [2500, 5000]),
];

export const mockTableBlankValues = [
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
  mockTableRow('-', '-', '-', '-', '-', ['-', '-']),
];

export const mockTableZeroValues = [
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
  mockTableRow(0, 0, 0, 0, 0, [0, 0]),
];
