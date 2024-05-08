import { GlEmptyState } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { createMockApolloProvider } from './apollo_util';

describe('Policy Editor', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider(),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures: {
          pipelineExecutionPolicyType: true,
          ...glFeatures,
        },
        ...provide,
      },
    });
  };

  const findSelectPipelineExecutionPolicyButton = () =>
    wrapper.findByTestId('select-policy-pipeline_execution_policy');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findRuleSection = () => wrapper.findComponent(RuleSection);

  describe('rendering with ff on', () => {
    beforeEach(() => {
      createWrapper();
      findSelectPipelineExecutionPolicyButton().vm.$emit('click');
    });

    it('renders the page correctly', () => {
      expect(findEmptyState().exists()).toBe(false);
      expect(findActionSection().exists()).toBe(true);
      expect(findRuleSection().exists()).toBe(true);
    });
  });

  describe('rendering with ff off', () => {
    it('should not render type selector for pipeline execution policy', () => {
      createWrapper({
        provide: {
          glFeatures: {
            pipelineExecutionPolicyType: false,
          },
        },
      });

      expect(findSelectPipelineExecutionPolicyButton().exists()).toBe(false);
    });
  });
});
