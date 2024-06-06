import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  createPolicyObject,
  fromYaml,
  policyToYaml,
  toYaml,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import {
  customYaml,
  customYamlObject,
  invalidStrategyManifest,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

describe('fromYaml', () => {
  it.each`
    title                                                                                        | input                                                                                 | output
    ${'returns the policy object for a supported manifest'}                                      | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }}                                    | ${fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY })}
    ${'returns the policy object for a supported manifest with scope with validation'}           | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE, validateRuleMode: true }} | ${fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE })}
    ${'returns the policy object for a policy with an unsupported attribute without validation'} | ${{ manifest: customYaml }}                                                           | ${customYamlObject}
    ${'returns the error object for a policy with an unsupported attribute with validation'}     | ${{ manifest: customYaml, validateRuleMode: true }}                                   | ${{ error: true }}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                           | input                                | output
    ${'returns the policy object and no errors for a supported manifest'}           | ${DEFAULT_PIPELINE_EXECUTION_POLICY} | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }), hasParsingError: false }}
    ${'returns the error policy object and the error for an unsupported manifest'}  | ${customYaml}                        | ${{ policy: { error: true }, hasParsingError: true }}
    ${'returns the error policy object and the error for an invalid strategy name'} | ${invalidStrategyManifest}           | ${{ policy: { error: true }, hasParsingError: true }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('policyToYaml', () => {
  it('returns policy object as yaml', () => {
    expect(policyToYaml(customYamlObject)).toBe(customYaml);
  });
});

describe('toYaml', () => {
  it('returns policy object as yaml', () => {
    expect(toYaml(customYamlObject)).toBe(customYaml);
  });
});
