import { GlTable, GlDrawer } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as urlUtils from '~/lib/utils/url_utility';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';

import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
  PIPELINE_EXECUTION_FILTER_OPTION,
} from 'ee/security_orchestration/components/policies/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { trimText } from 'helpers/text_helper';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  groupPipelineResultPolicies,
  projectPipelineResultPolicies,
  mockLinkedSppItemsResponse,
} from '../../mocks/mock_apollo';
import {
  mockGroupScanExecutionPolicy,
  mockScanExecutionPoliciesResponse,
} from '../../mocks/mock_scan_execution_policy_data';
import {
  mockScanResultPoliciesResponse,
  mockGroupScanResultPolicy,
  mockProjectScanResultPolicy,
} from '../../mocks/mock_scan_result_policy_data';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';

Vue.use(VueApollo);

const namespacePath = 'path/to/project/or/group';
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

describe('List component', () => {
  let wrapper;
  let requestHandlers;

  const factory = (mountFn = mountExtended) => ({ handlers = {}, provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mountFn(ListComponent, {
      propsData: {
        documentationPath: 'documentation_path',
      },
      provide: {
        customCiToggleEnabled: false,
        documentationPath: 'path/to/docs',
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        newPolicyPath: `${namespacePath}/-/security/policies/new`,
        disableScanPolicyUpdate: false,
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
      stubs: {
        DrawerWrapper: stubComponent(DrawerWrapper, {
          props: {
            ...DrawerWrapper.props,
            ...GlDrawer.props,
          },
        }),
        NoPoliciesEmptyState: true,
      },
    });

    document.title = 'Test title';
    jest.spyOn(urlUtils, 'updateHistory');
  };
  const mountShallowWrapper = factory(shallowMountExtended);
  const mountWrapper = factory();

  const findPolicySourceFilter = () => wrapper.findByTestId('policy-source-filter');
  const findPolicyTypeFilter = () => wrapper.findByTestId('policy-type-filter');
  const findPoliciesTable = () => wrapper.findComponent(GlTable);
  const findListComponentScope = () => wrapper.findComponent(ListComponentScope);
  const findPolicyStatusCells = () => wrapper.findAllByTestId('policy-status-cell');
  const findPolicySourceCells = () => wrapper.findAllByTestId('policy-source-cell');
  const findPolicyTypeCells = () => wrapper.findAllByTestId('policy-type-cell');
  const findPolicyDrawer = () => wrapper.findByTestId('policyDrawer');
  const findPolicyScopeCells = () => wrapper.findAllByTestId('policy-scope-cell');

  beforeEach(() => {
    window.gon.features = { pipelineExecutionPolicyType: false };
  });

  describe('initial state', () => {
    it('renders closed editor drawer', () => {
      mountShallowWrapper();

      const editorDrawer = findPolicyDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props('open')).toBe(false);
    });

    it('fetches policies', () => {
      mountShallowWrapper();

      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
      expect(requestHandlers.groupScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectScanResultPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
      expect(requestHandlers.groupScanResultPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.groupPipelineExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).not.toHaveBeenCalled();
    });

    it("sets table's loading state", () => {
      mountShallowWrapper({});

      expect(findPoliciesTable().attributes('busy')).toBe('true');
    });
  });

  describe('given policies have been fetched', () => {
    let rows;

    beforeEach(async () => {
      mountWrapper();
      await waitForPromises();
      rows = wrapper.findAll('tr');
    });

    describe.each`
      rowIndex | expectedPolicyName                           | expectedPolicyType
      ${1}     | ${mockScanExecutionPoliciesResponse[0].name} | ${'Scan execution'}
      ${3}     | ${mockScanResultPoliciesResponse[0].name}    | ${'Merge request approval'}
    `('policy in row #$rowIndex', ({ rowIndex, expectedPolicyName, expectedPolicyType }) => {
      let row;

      beforeEach(() => {
        row = rows.at(rowIndex);
      });

      it(`renders ${expectedPolicyName} in the name cell`, () => {
        expect(row.findAll('td').at(1).text()).toBe(expectedPolicyName);
      });

      it(`renders ${expectedPolicyType} in the policy type cell`, () => {
        expect(row.findAll('td').at(2).text()).toBe(expectedPolicyType);
      });
    });

    it.each`
      description         | filterBy                                     | hiddenTypes
      ${'scan execution'} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION} | ${[POLICY_TYPE_FILTER_OPTIONS.APPROVAL]}
      ${'scan result'}    | ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL}       | ${[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION]}
    `('policies filtered by $description type', async ({ filterBy, hiddenTypes }) => {
      findPolicyTypeFilter().vm.$emit('input', filterBy.value);
      await nextTick();

      expect(findPoliciesTable().text()).toContain(filterBy.text);
      hiddenTypes.forEach((hiddenType) => {
        expect(findPoliciesTable().text()).not.toContain(hiddenType.text);
      });
    });

    it('updates url when type filter is selected', async () => {
      findPolicyTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      await waitForPromises();

      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()}`,
        replace: true,
      });
    });

    it('does emit `update-policy-list` and refetch scan execution policies on `shouldUpdatePolicyList` change to `true`', async () => {
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('update-policy-list')).toBeUndefined();
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(wrapper.emitted('update-policy-list')).toStrictEqual([[{}]]);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });

    it('does not emit `update-policy-list` or refetch scan execution policies on `shouldUpdatePolicyList` change to `false`', async () => {
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
      wrapper.setProps({ shouldUpdatePolicyList: false });
      await nextTick();
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('group-level policies', () => {
    beforeEach(async () => {
      mountShallowWrapper({
        provide: {
          namespacePath,
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
      await waitForPromises();
    });

    it('does not fetch policies', () => {
      expect(requestHandlers.projectScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
      expect(requestHandlers.projectScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupScanResultPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
    });
  });

  describe('status column', () => {
    beforeEach(async () => {
      mountWrapper();
      await waitForPromises();
    });

    it('renders a checkmark icon for enabled policies', () => {
      const icon = findPolicyStatusCells().at(0).find('svg');

      expect(icon.exists()).toBe(true);
      expect(icon.props()).toMatchObject({
        name: 'check-circle-filled',
        ariaLabel: 'Enabled',
      });
    });

    it('renders a "Disabled" label for screen readers for disabled policies', () => {
      const span = findPolicyStatusCells().at(2).find('span');

      expect(span.exists()).toBe(true);
      expect(span.attributes('class')).toBe('gl-sr-only');
      expect(span.text()).toBe('Disabled');
    });
  });

  describe('source column', () => {
    beforeEach(async () => {
      mountWrapper();
      await waitForPromises();
    });

    it('renders when the policy is not inherited', () => {
      expect(findPolicySourceCells().at(0).text()).toBe('This project');
    });

    it('renders when the policy is inherited', () => {
      expect(trimText(findPolicySourceCells().at(1).text())).toBe(
        'Inherited from parent-group-name',
      );
    });

    it('renders inherited policy without namespace', async () => {
      mountWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handlers: {
          groupScanResultPolicies: projectScanResultPolicies([
            {
              ...mockProjectScanResultPolicy,
              ...{
                source: {
                  __typename: 'GroupSecurityPolicySource',
                  inherited: true,
                  namespace: undefined,
                },
              },
            },
          ]),
        },
      });

      await waitForPromises();

      expect(trimText(findPolicySourceCells().at(1).text())).toBe(
        'Inherited from parent-group-name',
      );
    });
  });

  describe.each`
    description         | policy                                  | policyType
    ${'scan execution'} | ${mockScanExecutionPoliciesResponse[0]} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}
    ${'scan result'}    | ${mockScanResultPoliciesResponse[0]}    | ${POLICY_TYPE_COMPONENT_OPTIONS.approval.value}
  `('given there is a $description policy selected', ({ policy, policyType }) => {
    beforeEach(() => {
      mountShallowWrapper();
      findPoliciesTable().vm.$emit('row-selected', [policy]);
    });

    it('renders opened editor drawer', () => {
      const editorDrawer = findPolicyDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props()).toMatchObject({
        open: true,
        policy,
        policyType,
      });
    });
  });

  describe('policy drawer', () => {
    it('should close drawer when new security project is selected', async () => {
      const scanExecutionPolicy = mockScanExecutionPoliciesResponse[0];

      mountShallowWrapper();
      findPoliciesTable().vm.$emit('row-selected', [scanExecutionPolicy]);
      await nextTick();

      expect(findPolicyDrawer().props('open')).toEqual(true);
      expect(findPolicyDrawer().props('policy')).toEqual(scanExecutionPolicy);

      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();

      expect(findPolicyDrawer().props('open')).toEqual(false);
      expect(findPolicyDrawer().props('policy')).toEqual(null);
    });
  });

  describe('inherited filter', () => {
    beforeEach(async () => {
      mountWrapper({
        handlers: {
          projectScanExecutionPolicies: projectScanExecutionPolicies([
            mockGroupScanExecutionPolicy,
          ]),
          projectScanResultPolicies: projectScanResultPolicies([mockGroupScanResultPolicy]),
        },
      });
      await waitForPromises();

      findPolicySourceFilter().vm.$emit('input', POLICY_SOURCE_OPTIONS.INHERITED.value);
      await waitForPromises();
    });

    it('displays inherited policies only', () => {
      expect(findPolicySourceCells()).toHaveLength(2);
      expect(trimText(findPolicySourceCells().at(0).text())).toBe(
        'Inherited from parent-group-name',
      );
      expect(trimText(findPolicySourceCells().at(1).text())).toBe(
        'Inherited from parent-group-name',
      );
    });

    it('updates url when source filter is selected', () => {
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?source=${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()}`,
        replace: true,
      });
    });

    it('displays inherited scan execution policies', () => {
      expect(trimText(findPolicyTypeCells().at(0).text())).toBe(
        POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
      );
    });

    it('displays inherited scan result policies', () => {
      expect(trimText(findPolicyTypeCells().at(1).text())).toBe(
        POLICY_TYPE_FILTER_OPTIONS.APPROVAL.text,
      );
    });
  });

  describe('selected url parameters', () => {
    it.each`
      value                                              | expectedType                                       | expectedSource
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_SOURCE_OPTIONS.ALL.value}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value} | ${POLICY_SOURCE_OPTIONS.ALL.value}
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}              | ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_SOURCE_OPTIONS.DIRECT.value}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}           | ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}            | ${POLICY_SOURCE_OPTIONS.INHERITED.value}
    `(
      'should select filters when parameters are in url',
      ({ value, expectedType, expectedSource }) => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(value);

        mountWrapper();

        expect(findPolicySourceFilter().props('value')).toBe(expectedSource);
        expect(findPolicyTypeFilter().props('value')).toBe(expectedType);
        expect(findPolicyScopeCells()).toHaveLength(0);
      },
    );
  });

  describe('scope column', () => {
    const SCOPE_HEADER_FIELD = {
      key: 'scope',
      label: 'Scope',
      sortable: true,
      tdAttr: { 'data-testid': 'policy-scope-cell' },
    };

    it('renders scope column on group level', async () => {
      mountShallowWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          glFeatures: {
            securityPoliciesPolicyScope: true,
          },
        },
      });

      await waitForPromises();

      expect(findPoliciesTable().props('fields')[4]).toEqual(SCOPE_HEADER_FIELD);
    });

    it('renders scope column on project level', async () => {
      mountShallowWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
          glFeatures: {
            securityPoliciesPolicyScopeProject: true,
          },
        },
      });

      await waitForPromises();

      expect(findPoliciesTable().props('fields')[4]).toEqual(SCOPE_HEADER_FIELD);
    });

    it('renders policy scope column inside table on group level', async () => {
      mountWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          glFeatures: {
            securityPoliciesPolicyScope: true,
          },
        },
      });

      await waitForPromises();

      expect(findPolicyScopeCells()).toHaveLength(4);
      expect(findListComponentScope().exists()).toBe(true);
    });

    it.each`
      securityPoliciesPolicyScopeProject | expectedLength
      ${true}                            | ${4}
      ${false}                           | ${0}
    `(
      'renders policy scope column inside table on project level when ff enabled',
      async ({ securityPoliciesPolicyScopeProject, expectedLength }) => {
        mountWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            glFeatures: {
              securityPoliciesPolicyScopeProject,
            },
          },
        });

        await waitForPromises();

        expect(findPolicyScopeCells()).toHaveLength(expectedLength);
        expect(findListComponentScope().exists()).toBe(securityPoliciesPolicyScopeProject);
      },
    );
  });

  describe('invalid policies', () => {
    it('renders breaking changes icon when flag is enabled but there are deprecated properties in scan result policies', async () => {
      mountWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['test', 'test1'] },
          ]),
        },
      });
      await waitForPromises();
      expect(wrapper.emitted('has-invalid-policies')).toEqual([[true]]);
    });
  });

  describe('breaking changes icon', () => {
    it('does not render breaking changes icon when flag is disabled', async () => {
      mountWrapper();
      await waitForPromises();

      const icons = findPolicyStatusCells().at(0).findAll('svg');

      expect(icons.length).toBe(1);
      expect(icons.at(0).props('name')).toBe('check-circle-filled');
    });

    it('does not render breaking changes icon when there are no deprecated properties', async () => {
      mountWrapper();

      await waitForPromises();

      const icons = findPolicyStatusCells().at(0).findAll('svg');

      expect(icons.length).toBe(1);
      expect(icons.at(0).props('name')).toBe('check-circle-filled');
    });

    it('renders breaking changes icon when there are deprecated properties', async () => {
      mountWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            {
              ...mockProjectScanResultPolicy,
              deprecatedProperties: ['test', 'test1'],
            },
          ]),
        },
      });

      await waitForPromises();

      const icon = findPolicyStatusCells().at(2).find('svg');

      expect(icon.props('name')).toBe('warning');
    });
  });

  describe('pipeline execution filter option', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: true };
    });

    it('updates url when type filter is selected', () => {
      mountShallowWrapper({
        provide: {
          customCiToggleEnabled: true,
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        },
      });

      findPolicyTypeFilter().vm.$emit(
        'input',
        PIPELINE_EXECUTION_FILTER_OPTION.PIPELINE_EXECUTION.value,
      );

      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?type=${PIPELINE_EXECUTION_FILTER_OPTION.PIPELINE_EXECUTION.value.toLowerCase()}`,
        replace: true,
      });
    });

    it('fetches pipeline execution policies on project level', () => {
      mountShallowWrapper({
        provide: {
          customCiToggleEnabled: true,
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        },
      });

      expect(requestHandlers.projectPipelineExecutionPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
    });

    it('fetches pipeline execution policies on group level', () => {
      mountShallowWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          customCiToggleEnabled: true,
          glFeatures: {
            pipelineExecutionPolicyType: true,
          },
        },
      });

      expect(requestHandlers.groupPipelineExecutionPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
      });
    });
  });
});
