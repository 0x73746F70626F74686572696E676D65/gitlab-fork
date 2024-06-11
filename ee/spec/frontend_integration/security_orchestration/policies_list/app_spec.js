import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  projectPipelineResultPolicies,
  groupPipelineResultPolicies,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { mockScanExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import { mockPipelineExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from './mocks';

Vue.use(VueApollo);

const projectScanExecutionPoliciesSpy = projectScanExecutionPolicies(
  mockScanExecutionPoliciesResponse,
);
const groupScanExecutionPoliciesSpy = groupScanExecutionPolicies(mockScanExecutionPoliciesResponse);
const projectScanResultPoliciesSpy = projectScanResultPolicies(mockScanResultPoliciesResponse);
const groupScanResultPoliciesSpy = groupScanResultPolicies(mockScanResultPoliciesResponse);
const projectPipelineExecutionPoliciesSpy = projectPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);
const groupPipelineExecutionPoliciesSpy = groupPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);

const defaultRequestHandlers = {
  projectScanExecutionPolicies: projectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: groupScanExecutionPoliciesSpy,
  projectScanResultPolicies: projectScanResultPoliciesSpy,
  groupScanResultPolicies: groupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: projectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: groupPipelineExecutionPoliciesSpy,
};

describe('Policies List', () => {
  let wrapper;
  let requestHandlers;

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  const createWrapper = ({ handlers = [], provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mount(App, {
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
        [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
        [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
        [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
        [projectPipelineExecutionPoliciesQuery, requestHandlers.projectPipelineExecutionPolicies],
        [groupPipelineExecutionPoliciesQuery, requestHandlers.groupPipelineExecutionPolicies],
      ]),
    });
  };

  describe('project level with pipelineExecutionPolicyType feature flag off', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: false };
      createWrapper();
    });

    it('renders the page correctly', () => {
      expect(findPoliciesHeader().exists()).toBe(true);
      expect(findPoliciesList().exists()).toBe(true);
    });

    it('fetches correct policies on project level', () => {
      expect(requestHandlers.groupScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).not.toHaveBeenCalled();
    });
  });

  describe('project level with pipelineExecutionPolicyType feature flag on', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: true };
      createWrapper({
        provide: {
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        },
      });
    });

    it('renders the page correctly with ff enabled', () => {
      expect(findPoliciesHeader().exists()).toBe(true);
      expect(findPoliciesList().exists()).toBe(true);
    });

    it('fetches correct policies on project level with ff enabled', () => {
      expect(requestHandlers.groupScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).toHaveBeenCalled();
    });
  });

  describe('group level with pipelineExecutionPolicyType feature flag off', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: false };
      createWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).not.toHaveBeenCalled();
    });
  });

  describe('group level with pipelineExecutionPolicyType feature flag on', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: true };
      createWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        },
      });
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).not.toHaveBeenCalled();
    });
  });
});
