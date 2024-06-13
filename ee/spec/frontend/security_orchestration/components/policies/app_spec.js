import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { POLICY_SOURCE_OPTIONS } from 'ee/security_orchestration/components/policies/constants';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  groupPipelineResultPolicies,
  projectPipelineResultPolicies,
  mockLinkedSppItemsResponse,
} from '../../mocks/mock_apollo';
import { mockScanExecutionPoliciesResponse } from '../../mocks/mock_scan_execution_policy_data';
import {
  mockScanResultPoliciesResponse,
  mockProjectScanResultPolicy,
} from '../../mocks/mock_scan_result_policy_data';

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

const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();
const defaultRequestHandlers = {
  projectScanExecutionPolicies: projectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: groupScanExecutionPoliciesSpy,
  projectScanResultPolicies: projectScanResultPoliciesSpy,
  groupScanResultPolicies: groupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: projectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: groupPipelineExecutionPoliciesSpy,
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
};

describe('App', () => {
  let wrapper;
  let requestHandlers;
  const namespacePath = 'path/to/project/or/group';

  const createWrapper = ({ assignedPolicyProject = null, handlers = {}, provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = shallowMountExtended(App, {
      provide: {
        assignedPolicyProject,
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
        [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
        [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
        [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
        [getSppLinkedProjectsNamespaces, requestHandlers.linkedSppItemsResponse],
        [projectPipelineExecutionPoliciesQuery, requestHandlers.projectPipelineExecutionPolicies],
        [groupPipelineExecutionPoliciesQuery, requestHandlers.groupPipelineExecutionPolicies],
      ]),
    });
  };

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  describe('loading', () => {
    it('renders the policies list correctly when pipelineExecutionPolicyType is false', () => {
      createWrapper();
      expect(findPoliciesList().props('isLoadingPolicies')).toBe(true);
    });

    it('renders the policies list correctly when pipelineExecutionPolicyType is true', () => {
      createWrapper({ provide: { glFeatures: { pipelineExecutionPolicyType: true } } });
      expect(findPoliciesList().props('isLoadingPolicies')).toBe(true);
    });
  });

  describe('default', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the policies list correctly', () => {
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
    });

    it('renders the policy header correctly', () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
    });

    it('fetches linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(1);
    });

    it('updates the policy list when a the security policy project is changed', async () => {
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
      findPoliciesHeader().vm.$emit('update-policy-list', {
        shouldUpdatePolicyList: true,
        hasPolicyProject: true,
      });
      await nextTick();
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(true);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });

    it.each`
      type                | groupHandler                    | projectHandler
      ${'scan execution'} | ${'groupScanExecutionPolicies'} | ${'projectScanExecutionPolicies'}
      ${'scan result'}    | ${'groupScanResultPolicies'}    | ${'projectScanResultPolicies'}
    `(
      'fetches project-level $type policies instead of group-level',
      ({ groupHandler, projectHandler }) => {
        createWrapper();
        expect(requestHandlers[groupHandler]).not.toHaveBeenCalled();
        expect(requestHandlers[projectHandler]).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        });
      },
    );

    describe('when pipelineExecutionPolicyEnabled is false', () => {
      it.each`
        type                    | groupHandler                        | projectHandler
        ${'pipeline execution'} | ${'groupPipelineExecutionPolicies'} | ${'projectPipelineExecutionPolicies'}
      `(
        'does not fetch group-level or project-level $type policies',
        ({ groupHandler, projectHandler }) => {
          createWrapper();
          expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
          expect(requestHandlers[groupHandler]).not.toHaveBeenCalledWith();
        },
      );
    });

    describe('when pipelineExecutionPolicyEnabled is true', () => {
      beforeEach(async () => {
        createWrapper({
          provide: { glFeatures: { pipelineExecutionPolicyType: true } },
        });
        await waitForPromises();
      });

      it.each`
        type                    | groupHandler                        | projectHandler
        ${'pipeline execution'} | ${'groupPipelineExecutionPolicies'} | ${'projectPipelineExecutionPolicies'}
      `(
        'fetches project-level $type policies instead of group-level',
        ({ groupHandler, projectHandler }) => {
          expect(requestHandlers[groupHandler]).not.toHaveBeenCalled();
          expect(requestHandlers[projectHandler]).toHaveBeenCalledWith({
            fullPath: namespacePath,
            relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          });
        },
      );
    });
  });

  it('renders correctly when a policy project is linked', async () => {
    createWrapper({ assignedPolicyProject: { id: '1' } });
    await nextTick();

    expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
  });

  describe('group-level policies', () => {
    it('does not fetch linked SPP items', async () => {
      createWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      await waitForPromises();
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(0);
    });

    describe('when pipelineExecutionPolicyEnabled is false', () => {
      beforeEach(async () => {
        createWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
        await waitForPromises();
      });

      it.each`
        type                | groupHandler                    | projectHandler
        ${'scan execution'} | ${'groupScanExecutionPolicies'} | ${'projectScanExecutionPolicies'}
        ${'scan result'}    | ${'groupScanResultPolicies'}    | ${'projectScanResultPolicies'}
      `(
        'fetches group-level $type policies instead of project-level',
        ({ groupHandler, projectHandler }) => {
          expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
          expect(requestHandlers[groupHandler]).toHaveBeenCalledWith({
            fullPath: namespacePath,
            relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          });
        },
      );

      it.each`
        type                    | groupHandler                        | projectHandler
        ${'pipeline execution'} | ${'groupPipelineExecutionPolicies'} | ${'projectPipelineExecutionPolicies'}
      `(
        'fetches group-level $type policies instead of project-level',
        ({ groupHandler, projectHandler }) => {
          expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
          expect(requestHandlers[groupHandler]).not.toHaveBeenCalledWith();
        },
      );
    });

    describe('when pipelineExecutionPolicyEnabled is true', () => {
      beforeEach(async () => {
        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
            glFeatures: { pipelineExecutionPolicyType: true },
          },
        });
        await waitForPromises();
      });

      it.each`
        type                    | groupHandler                        | projectHandler
        ${'pipeline execution'} | ${'groupPipelineExecutionPolicies'} | ${'projectPipelineExecutionPolicies'}
      `(
        'fetches group-level $type policies instead of project-level',
        ({ groupHandler, projectHandler }) => {
          expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
          expect(requestHandlers[groupHandler]).toHaveBeenCalledWith({
            fullPath: namespacePath,
            relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          });
        },
      );
    });
  });

  describe('invalid policies', () => {
    it('updates "hasInvalidPolicies" when there are deprecated properties in scan result policies that are not "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['test', 'test1'] },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are deprecated properties in scan result policies that are "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['scan_result_policy'] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: [] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });
  });
});
