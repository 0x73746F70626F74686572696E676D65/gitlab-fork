export const mockSecretDetectionScanExecutionManifest = `---
name: Enforce DAST in every pipeline
enabled: false,
rules:
- type: pipeline
  branches:
  - main
  - release/*
  - staging
actions:
- scan: secret_detection
`;

export const mockDastAndSecretDetectionScanExecutionManifest = `---
name: Enforce DAST in every pipeline
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: true
rules:
- type: schedule
  cadence: "*/10 * * * *"
  branches:
  - main
- type: pipeline
  branches:
  - main
  - release/*
  - staging
actions:
- scan: dast
  scanner_profile: Scanner Profile
  site_profile: Site Profile
- scan: secret_detection
`;

export const mockEnvironmentsResponse = {
  environments: [
    {
      id: 1129970,
      name: 'production',
      state: 'available',
    },
    {
      id: 1156094,
      name: 'review/enable-network-policies',
      state: 'available',
    },
  ],
  available_count: 2,
  stopped_count: 5,
};

export const mockScanExecutionManifestNoActions = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions: []
`;

export const mockDastScanExecutionManifest = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: dast
    site_profile: required_site_profile
    scanner_profile: required_scanner_profile
`;

export const mockScanExecutionManifestMultipleActions = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: container_scanning
  - scan: secret_detection
  - scan: sast
`;

export const mockDastScanExecutionObject = {
  type: 'scan_execution_policy',
  name: 'Test Dast',
  description: 'This policy enforces pipeline configuration to have a job with DAST scan',
  enabled: false,
  rules: [{ type: 'pipeline', branches: ['main'] }],
  actions: [
    {
      scan: 'dast',
      site_profile: 'required_site_profile',
      scanner_profile: 'required_scanner_profile',
    },
  ],
};

export const mockScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  name: 'Scheduled DAST scan',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDastScanExecutionManifest,
  enabled: true,
  latestScan: { date: new Date('2021-06-07T00:00:00.000Z'), pipelineUrl: 'path/to/pipeline' },
};

export const mockScanResultManifest = `type: scan_result_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockScanResultManifestSecond = `type: scan_result_policy
name: low vulnerability SAST approvals
description: This policy enforces low vulnerability SAST approvals
enabled: true
rules:
  - type: scan_finding
    branches:
      - main
    scanners:
      - sast
    vulnerabilities_allowed: 1
    severity_levels:
      - low
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockScanResultObject = {
  type: 'scan_result_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
    },
  ],
};

export const mockScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  name: 'critical vulnerability CS approvals',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockScanResultManifest,
  enabled: false,
};

export const mockScanResultPolicySecond = {
  __typename: 'ScanResultPolicy',
  name: 'low vulnerability sast approvals second',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockScanResultManifestSecond,
  enabled: true,
};

export const mockScanExecutionPoliciesResponse = [mockScanExecutionPolicy];

export const mockScanResultPoliciesResponse = [mockScanResultPolicy];

export const mockNominalHistory = [
  ['2019-12-04T00:00:00.000Z', 56],
  ['2019-12-05T00:00:00.000Z', 2647],
];

export const mockAnomalousHistory = [
  ['2019-12-04T00:00:00.000Z', 1],
  ['2019-12-05T00:00:00.000Z', 83],
];

export const mockNetworkPolicyStatisticsResponse = {
  ops_total: {
    total: 2703,
    drops: 84,
  },
  ops_rate: {
    total: [
      [1575417600, 56],
      [1575504000, 2647],
    ],
    drops: [
      [1575417600, 1],
      [1575504000, 83],
    ],
  },
};

export const formattedMockNetworkPolicyStatisticsResponse = {
  opsRate: {
    drops: [
      [new Date('2019-12-04T00:00:00.000Z'), 1],
      [new Date('2019-12-05T00:00:00.000Z'), 83],
    ],
    total: [
      [new Date('2019-12-04T00:00:00.000Z'), 56],
      [new Date('2019-12-05T00:00:00.000Z'), 2647],
    ],
  },
  opsTotal: { drops: 84, total: 2703 },
};

export const mockAlerts = [
  {
    __typename: 'AlertManagementAlert',
    iid: '01',
    title: 'Issue 01',
    severity: 'HIGH',
    status: 'TRIGGERED',
    startedAt: '2020-11-19T18:36:23Z',
    eventCount: '1',
    issue: {
      id: 'issue-1',
      iid: '5',
      state: 'opened',
      title: 'Issue 01',
      webUrl: 'http://test.com/05',
    },
    assignees: {
      nodes: [
        {
          __typename: 'UserCore',
          id: 'Alert:1',
          name: 'Administrator',
          username: 'root',
          avatarUrl: '/test-avatar-url',
          webUrl: 'https://gitlab:3443/root',
        },
      ],
    },
  },
  {
    __typename: 'AlertManagementAlert',
    iid: '02',
    title: 'Issue 02',
    severity: 'CRITICAL',
    status: 'ACKNOWLEDGED',
    startedAt: '2020-11-16T21:59:28Z',
    eventCount: '2',
    issue: {
      id: 'issue-2',
      iid: '6',
      state: 'closed',
      title: 'Issue 02',
      webUrl: 'http://test.com/06',
    },
    assignees: { nodes: [] },
  },
  {
    __typename: 'AlertManagementAlert',
    iid: '03',
    title: 'Issue 03',
    severity: 'MEDIUM',
    status: 'RESOLVED',
    startedAt: '2020-11-13T20:03:04Z',
    eventCount: '3',
    issue: null,
    assignees: { nodes: [] },
  },
  {
    __typename: 'AlertManagementAlert',
    iid: '04',
    title: 'Issue 04',
    severity: 'LOW',
    status: 'IGNORED',
    startedAt: '2020-10-29T13:37:55Z',
    eventCount: '4',
    issue: null,
    assignees: { nodes: [] },
  },
];

export const mockPageInfo = {
  endCursor: 'eyJpZCI6IjIwIiwic3RhcnRlZF9hdCI6IjIwMjAtMTItMDMgMjM6MTI6NDkuODM3Mjc1MDAwIFVUQyJ9',
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjM5Iiwic3RhcnRlZF9hdCI6IjIwMjAtMTItMDQgMTg6MDE6MDcuNzY1ODgyMDAwIFVUQyJ9',
};

export const mockAlertDetails = {
  ...mockAlerts[0],
  createdAt: '2020-10-29T13:37:55Z',
  monitoringTool: 'Cilium',
  metricsDashboardUrl: 'www.test.com',
  service: '',
  description: 'triggered alert',
  updatedAt: '2020-10-29T13:37:55Z',
  endedAt: null,
  hosts: [],
  environment: null,
  details: {},
  runbook: null,
  todos: { nodes: [{ id: 'gid://gitlab/Todo/5984130' }] },
  notes: { nodes: [] },
};
