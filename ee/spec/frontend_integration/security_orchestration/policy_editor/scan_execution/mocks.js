const mockScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`;

export const mockDastActionScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: dast
    site_profile: ''
    scanner_profile: ''
`;

export const mockGroupDastActionScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: dast
    site_profile: ''
    scanner_profile: ''
`;

export const mockActionsVariablesScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
    variables:
      '': ''
`;

export const createScanActionScanExecutionManifest = (scanType) =>
  mockScanExecutionManifest.replace('scan: secret_detection', `scan: ${scanType}`);

export const mockPipelineScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`;

export const mockScheduleScanExecutionManifest = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: schedule
    branches: []
    cadence: 0 0 * * *
actions:
  - scan: secret_detection
`;
