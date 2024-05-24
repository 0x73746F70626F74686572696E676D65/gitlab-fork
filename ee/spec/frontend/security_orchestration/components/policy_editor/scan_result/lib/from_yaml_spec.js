import {
  createPolicyObject,
  fromYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  collidingKeysScanResultManifest,
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockApprovalSettingsScanResultManifest,
  mockApprovalSettingsScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultManifest,
  mockApprovalSettingsPermittedInvalidScanResultObject,
  mockPolicyScopeScanResultManifest,
  mockPolicyScopeScanResultObject,
  tooManyActionsScanResultManifest,
  duplicateActionsScanResultManifest,
  zeroActionsScanResultManifest,
  zeroActionsScanResultObject,
  mockFallbackInvalidScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';

afterEach(() => {
  window.gon = {};
});

jest.mock('lodash/uniqueId', () => jest.fn((prefix) => `${prefix}0`));

describe('fromYaml', () => {
  it.each`
    title                                                                                                | input                                                                          | output
    ${'returns the policy object for a supported manifest without approval_settings'}                    | ${{ manifest: mockDefaultBranchesScanResultManifest }}                         | ${mockDefaultBranchesScanResultObject}
    ${'returns the policy object for a supported manifest with approval_settings'}                       | ${{ manifest: mockApprovalSettingsScanResultManifest }}                        | ${mockApprovalSettingsScanResultObject}
    ${'returns the error object for a policy with an unsupported attribute'}                             | ${{ manifest: unsupportedManifest, validateRuleMode: true }}                   | ${{ error: true }}
    ${'returns the error object for a policy with colliding self excluded keys'}                         | ${{ manifest: collidingKeysScanResultManifest, validateRuleMode: true }}       | ${{ error: true }}
    ${'returns the policy object for a policy without actions'}                                          | ${{ manifest: zeroActionsScanResultManifest, validateRuleMode: true }}         | ${zeroActionsScanResultObject}
    ${'returns the error object for a policy with more than two actions'}                                | ${{ manifest: tooManyActionsScanResultManifest, validateRuleMode: true }}      | ${{ error: true }}
    ${'returns the error object for a policy with duplicate action types'}                               | ${{ manifest: duplicateActionsScanResultManifest, validateRuleMode: true }}    | ${{ error: true }}
    ${'returns the policy object for a policy with fail: open'}                                          | ${{ manifest: zeroActionsScanResultManifest, validateRuleMode: true }}         | ${zeroActionsScanResultObject}
    ${'returns the policy object for a policy with fail: closed'}                                        | ${{ manifest: zeroActionsScanResultManifest, validateRuleMode: true }}         | ${zeroActionsScanResultObject}
    ${'returns the error object for a policy with unsupported fallback behavior'}                        | ${{ manifest: mockFallbackInvalidScanResultManifest, validateRuleMode: true }} | ${{ error: true }}
    ${'returns the policy object for a policy with an unsupported attribute when validation is skipped'} | ${{ manifest: unsupportedManifest }}                                           | ${unsupportedManifestObject}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                          | input                                    | output
    ${'returns the policy object and no errors for a supported manifest'}          | ${mockDefaultBranchesScanResultManifest} | ${{ policy: mockDefaultBranchesScanResultObject, hasParsingError: false }}
    ${'returns the error policy object and the error for an unsupported manifest'} | ${unsupportedManifest}                   | ${{ policy: { error: true }, hasParsingError: true }}
    ${'returns the error policy object and the error for an colliding keys'}       | ${collidingKeysScanResultManifest}       | ${{ policy: { error: true }, hasParsingError: true }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });

  describe('feature flag', () => {
    it.each`
      title                                                                                                       | features                                        | input                                                     | output
      ${'returns the policy object for a manifest with `policy_scope` feature flag on for project'}               | ${{ securityPoliciesPolicyScopeProject: true }} | ${mockPolicyScopeScanResultManifest}                      | ${{ policy: mockPolicyScopeScanResultObject, hasParsingError: false }}
      ${'returns the error object for a manifest with `approval_settings` containing permitted invalid settings'} | ${{}}                                           | ${mockApprovalSettingsPermittedInvalidScanResultManifest} | ${{ policy: mockApprovalSettingsPermittedInvalidScanResultObject, hasParsingError: false }}
      ${'returns the policy object for a manifest with `approval_settings` by default'}                           | ${{}}                                           | ${mockApprovalSettingsScanResultManifest}                 | ${{ policy: mockApprovalSettingsScanResultObject, hasParsingError: false }}
      ${'returns the policy object for a manifest with `policy_scope` by default'}                                | ${{}}                                           | ${mockPolicyScopeScanResultManifest}                      | ${{ policy: mockPolicyScopeScanResultObject, hasParsingError: false }}
    `('$title', ({ features, input, output }) => {
      window.gon = { features };
      expect(createPolicyObject(input)).toStrictEqual(output);
    });
  });
});
