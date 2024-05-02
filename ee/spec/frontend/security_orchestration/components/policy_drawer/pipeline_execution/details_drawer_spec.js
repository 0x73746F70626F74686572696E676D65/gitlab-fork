import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { mockProjectPipelineExecutionPolicy } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

describe('PipelineExecutionDrawer', () => {
  let wrapper;

  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findSummaryHeader = () => wrapper.findByTestId('summary-header');
  const findSummaryFields = () => wrapper.findAllByTestId('summary-fields');
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(PipelineExecutionDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('policy')).toEqual(mockProjectPipelineExecutionPolicy);
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces pipeline execution with configuration from external file',
      );
    });
  });

  describe('summary', () => {
    it('renders the policy summary', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      expect(findSummary().exists()).toBe(true);
      expect(findSummaryFields()).toHaveLength(1);
      expect(findSummaryFields().at(0).text()).toBe(
        'Project: gitlab-policies/js6Reference: mainPath: test_path',
      );
      expect(findSummaryHeader().text()).toBe('Enforce the following pipeline execution policy:');
    });
  });
});
