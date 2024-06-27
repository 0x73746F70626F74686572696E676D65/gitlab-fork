import {
  createPolicyObject,
  fromYaml,
  hasRuleModeSupportedScanners,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import {
  actionId,
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
  mockInvalidCadenceScanExecutionObject,
  mockInvalidYamlCadenceValue,
  mockBranchExceptionsScanExecutionObject,
  mockBranchExceptionsExecutionManifest,
  mockPolicyScopeExecutionManifest,
  mockPolicyScopeScanExecutionObject,
  mockCodeBlockFilePathScanExecutionManifest,
  mockCodeBlockFilePathScanExecutionObject,
  mockTemplateScanExecutionManifest,
  mockTemplateScanExecutionObject,
  mockInvalidTemplateScanExecutionManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

jest.mock('lodash/uniqueId', () => jest.fn((prefix) => `${prefix}0`));

describe('fromYaml', () => {
  it.each`
    title                                                                                                | input                                                                               | output                                      | features
    ${'returns the policy object for a supported manifest'}                                              | ${{ manifest: mockDastScanExecutionManifest }}                                      | ${mockDastScanExecutionObject}              | ${{}}
    ${'returns the error object for a policy with an unsupported attribute'}                             | ${{ manifest: unsupportedManifest, validateRuleMode: true }}                        | ${{ error: true }}                          | ${{}}
    ${'returns the policy object for a policy with an unsupported attribute when validation is skipped'} | ${{ manifest: unsupportedManifest }}                                                | ${unsupportedManifestObject}                | ${{}}
    ${'returns error object for a policy with invalid cadence cron string and validation mode'}          | ${{ manifest: mockInvalidCadenceScanExecutionObject, validateRuleMode: true }}      | ${{ error: true }}                          | ${{}}
    ${'returns error object for a policy with invalid cadence cron string'}                              | ${{ manifest: mockInvalidYamlCadenceValue }}                                        | ${{ error: true, key: 'yaml-parsing' }}     | ${{}}
    ${'returns the policy object for branch exceptions'}                                                 | ${{ manifest: mockBranchExceptionsExecutionManifest, validateRuleMode: true }}      | ${mockBranchExceptionsScanExecutionObject}  | ${{}}
    ${'returns the policy object for project scope'}                                                     | ${{ manifest: mockPolicyScopeExecutionManifest, validateRuleMode: true }}           | ${mockPolicyScopeScanExecutionObject}       | ${{}}
    ${'returns the policy object for custom code block with file path with enabled ff'}                  | ${{ manifest: mockCodeBlockFilePathScanExecutionManifest, validateRuleMode: true }} | ${mockCodeBlockFilePathScanExecutionObject} | ${{ compliancePipelineInPolicies: true }}
    ${'returns the policy object for custom code block with file path with disabled ff'}                 | ${{ manifest: mockCodeBlockFilePathScanExecutionManifest, validateRuleMode: true }} | ${{ error: true }}                          | ${{ compliancePipelineInPolicies: false }}
    ${'returns the policy object for valid template value'}                                              | ${{ manifest: mockTemplateScanExecutionManifest, validateRuleMode: true }}          | ${mockTemplateScanExecutionObject}          | ${{ compliancePipelineInPolicies: false }}
    ${'returns error object for a policy with invalid template value'}                                   | ${{ manifest: mockInvalidTemplateScanExecutionManifest, validateRuleMode: true }}   | ${{ error: true }}                          | ${{}}
  `('$title', ({ input, output, features }) => {
    window.gon = { features };
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                          | input                              | output
    ${'returns the policy object and no errors for a supported manifest'}          | ${[mockDastScanExecutionManifest]} | ${{ policy: mockDastScanExecutionObject, hasParsingError: false }}
    ${'returns the error policy object and the error for an unsupported manifest'} | ${[unsupportedManifest]}           | ${{ policy: { error: true }, hasParsingError: true }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(...input)).toStrictEqual(output);
  });
});

describe('hasRuleModeSupportedScanners', () => {
  it.each`
    title                                                 | input                                                                                              | output
    ${'return true when all scanners are supported'}      | ${{ actions: [{ scan: 'sast', id: actionId }, { scan: 'dast', id: actionId }] }}                   | ${true}
    ${'return false when not all scanners are supported'} | ${{ actions: [{ scan: 'sast', id: actionId }, { scan: 'cluster_image_scanning', id: actionId }] }} | ${false}
    ${'return true when no actions on policy'}            | ${{ name: 'test' }}                                                                                | ${true}
    ${'return false when no valid scanners'}              | ${{ actions: [{ scan2: 'sast' }, { scan3: 'cluster_image_scanning' }] }}                           | ${false}
  `('$title', ({ input, output }) => {
    expect(hasRuleModeSupportedScanners(input)).toBe(output);
  });
});
