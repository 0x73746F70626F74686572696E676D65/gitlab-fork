import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';

describe('PolicyTypeSelector component', () => {
  const policiesPath = '/policies/path';
  let wrapper;

  const factory = (provide = {}, stubs = {}) => {
    wrapper = shallowMountExtended(PolicyTypeSelector, {
      stubs: { GlCard: true, ...stubs },
      provide: {
        policiesPath,
        maxScanExecutionPoliciesAllowed: 5,
        maxScanResultPoliciesAllowed: 5,
        maxPipelineExecutionPoliciesAllowed: 1,
        maxActiveScanExecutionPoliciesReached: true,
        maxActiveScanResultPoliciesReached: false,
        maxActivePipelineExecutionPoliciesReached: false,
        ...provide,
      },
    });
  };

  const findPolicyButton = (urlParameter) => wrapper.findByTestId(`select-policy-${urlParameter}`);
  const findMaxAllowedPolicyText = (urlParameter) =>
    wrapper.findByTestId(`max-allowed-text-${urlParameter}`);

  describe('cards', () => {
    describe.each`
      title                                               | description
      ${PolicyTypeSelector.i18n.scanResultPolicyTitle}    | ${PolicyTypeSelector.i18n.scanResultPolicyDesc}
      ${PolicyTypeSelector.i18n.scanExecutionPolicyTitle} | ${PolicyTypeSelector.i18n.scanExecutionPolicyDesc}
    `('selection card: $title', ({ title, description }) => {
      beforeEach(() => {
        factory();
      });

      it(`displays the title`, () => {
        expect(wrapper.findByText(title).exists()).toBe(true);
      });

      it(`displays the description`, () => {
        expect(wrapper.findByText(description).exists()).toBe(true);
      });
    });

    describe('pipeline execution policy type', () => {
      beforeEach(() => {
        factory({
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        });
      });

      it(`displays the title`, () => {
        expect(
          wrapper.findByText(PolicyTypeSelector.i18n.pipelineExecutionPolicyTitle).exists(),
        ).toBe(true);
      });

      it(`displays the description`, () => {
        expect(
          wrapper.findByText(PolicyTypeSelector.i18n.pipelineExecutionPolicyDesc).exists(),
        ).toBe(true);
      });
    });

    describe('navigation button', () => {
      beforeEach(() => {
        factory();
      });

      it('displays the button for policy types that have not reached their max number allowed', () => {
        expect(findPolicyButton(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter).exists()).toBe(
          true,
        );
        expect(
          findMaxAllowedPolicyText(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter).exists(),
        ).toBe(false);
      });

      it('displays warning text for policy types that have reached their max number allowed', () => {
        expect(
          findPolicyButton(POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter).exists(),
        ).toBe(false);
        expect(
          findMaxAllowedPolicyText(
            POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          ).exists(),
        ).toBe(true);
        expect(
          findMaxAllowedPolicyText(POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter).text(),
        ).toBe('');
      });

      it('displays warning text for pipeline execution policy type', () => {
        factory(
          {
            maxActivePipelineExecutionPoliciesReached: true,
            glFeatures: {
              pipelineExecutionPolicyType: true,
            },
          },
          {
            GlSprintf,
          },
        );
        expect(
          findMaxAllowedPolicyText(
            POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          ).exists(),
        ).toBe(true);
        expect(
          findMaxAllowedPolicyText(
            POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          ).text(),
        ).toBe('You already have the maximum 1 pipeline execution policy.');
        expect(
          findPolicyButton(POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter).exists(),
        ).toBe(false);
      });
    });
  });

  it('displays a cancel button which brings back to policies page', () => {
    factory();
    expect(wrapper.findByTestId('back-button').attributes('href')).toBe(policiesPath);
  });

  it.each([
    POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
    POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
    POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
  ])('should emit selected policy type', (parameter) => {
    factory({
      maxActiveScanExecutionPoliciesReached: false,
      maxActiveScanResultPoliciesReached: false,
      glFeatures: {
        pipelineExecutionPolicyType: true,
      },
    });

    findPolicyButton(parameter).vm.$emit('click');

    expect(wrapper.emitted('select')).toEqual([[parameter]]);
  });
});
