import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { actionId, ruleId, unsupportedManifest, unsupportedManifestObject } from './mock_data';

export const customYaml = `variable: true
`;

export const customYamlObject = { variable: true };

export const mockUnsupportedAttributeScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  name: unsupportedManifestObject.name,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: unsupportedManifest,
  enabled: false,
  source: {
    __typename: 'ProjectSecurityPolicySource',
  },
};

export const mockDastScanExecutionManifest = `type: scan_execution_policy
name: Scheduled Dast/SAST scan
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

export const mockDastScanExecutionObject = {
  type: 'scan_execution_policy',
  name: 'Scheduled Dast/SAST scan',
  description: 'This policy enforces pipeline configuration to have a job with DAST scan',
  enabled: false,
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [
    {
      scan: 'dast',
      site_profile: 'required_site_profile',
      scanner_profile: 'required_scanner_profile',
      id: actionId,
    },
  ],
};

export const mockBranchExceptionsExecutionManifest = `type: scan_execution_policy
name: Branch exceptions
description: This policy enforces pipeline configuration to have branch exceptions
enabled: false
rules:
  - type: pipeline
    branches:
      - main
    branch_exceptions:
      - main
      - test
actions:
  - scan: dast
    site_profile: required_site_profile
    scanner_profile: required_scanner_profile
`;

export const mockBranchExceptionsScanExecutionObject = {
  type: 'scan_execution_policy',
  name: 'Branch exceptions',
  description: 'This policy enforces pipeline configuration to have branch exceptions',
  enabled: false,
  rules: [
    { type: 'pipeline', branches: ['main'], branch_exceptions: ['main', 'test'], id: ruleId },
  ],
  actions: [
    {
      scan: 'dast',
      site_profile: 'required_site_profile',
      scanner_profile: 'required_scanner_profile',
      id: actionId,
    },
  ],
};

export const mockProjectScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  name: `${mockDastScanExecutionObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDastScanExecutionManifest,
  editPath: '/policies/policy-name/edit?type="scan_execution_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockGroupScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  name: `${mockDastScanExecutionObject.name}-group`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDastScanExecutionManifest,
  editPath: '/policies/policy-name/edit?type="scan_execution_policy"',
  enabled: false,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockScanExecutionPoliciesResponse = [
  mockProjectScanExecutionPolicy,
  mockGroupScanExecutionPolicy,
];

export const mockSecretDetectionScanExecutionManifest = `---
name: Enforce DAST in every pipeline
enabled: false
rules:
- type: pipeline
  branches:
  - main
  - release/*
  - staging
actions:
- scan: secret_detection
  tags:
  - linux,
`;

export const mockCiVariablesWithTagsScanExecutionManifest = `---
name: Enforce Secret Detection in every pipeline
enabled: true
rules:
- type: pipeline
  branches:
  - main
actions:
- scan: secret_detection
  tags:
  - default
  variables:
    SECRET_DETECTION_HISTORIC_SCAN: 'true'
`;

export const mockInvalidYamlCadenceValue = `---
name: Enforce DAST in every pipeline
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: true
rules:
- type: schedule
  cadence: */10 * * * *
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

export const mockNoActionsScanExecutionManifest = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions: []
`;

export const mockMultipleActionsScanExecutionManifest = `type: scan_execution_policy
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

export const mockInvalidCadenceScanExecutionObject = {
  name: 'This policy has an invalid cadence',
  rules: [
    {
      type: 'pipeline',
      branches: ['main'],
      id: ruleId,
    },
    {
      type: 'schedule',
      branches: ['main'],
      cadence: '0 0 * * INVALID',
      id: ruleId,
    },
    {
      type: 'schedule',
      branches: ['main'],
      cadence: '0 0 * * *',
      id: ruleId,
    },
  ],
  actions: [{ scan: 'sast', id: actionId }],
};

export const mockPolicyScopeExecutionManifest = `type: scan_execution_policy
name: Project scope
description: This policy enforces policy scope
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: container_scanning
policy_scope:
  compliance_frameworks: []
`;

export const mockPolicyScopeScanExecutionObject = {
  type: 'scan_execution_policy',
  name: 'Project scope',
  enabled: false,
  description: 'This policy enforces policy scope',
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [{ scan: 'container_scanning', id: actionId }],
  policy_scope: {
    compliance_frameworks: [],
  },
};

export const mockCodeBlockFilePathScanExecutionManifest = `type: scan_execution_policy
name: Test File Path
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: sast
  - scan: custom
    ci_configuration:
      include:
        file: file
`;

export const mockCodeBlockFilePathScanExecutionObject = {
  type: 'scan_execution_policy',
  name: 'Test File Path',
  enabled: false,
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [
    { scan: 'sast', id: actionId },
    {
      scan: 'custom',
      ci_configuration: {
        include: {
          file: 'file',
        },
      },
      id: actionId,
    },
  ],
};

export const mockTemplateScanExecutionManifest = mockDastScanExecutionManifest.concat(
  `    template: default\n`,
);

export const mockTemplateScanExecutionObject = {
  ...mockDastScanExecutionObject,
  actions: [{ ...mockDastScanExecutionObject.actions[0], template: 'default' }],
};

export const mockInvalidTemplateScanExecutionManifest = mockDastScanExecutionManifest.concat(
  `    template: not-valid-value\n`,
);
