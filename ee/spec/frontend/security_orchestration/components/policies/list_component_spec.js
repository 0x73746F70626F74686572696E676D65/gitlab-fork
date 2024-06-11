import { GlTable, GlDrawer } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as urlUtils from '~/lib/utils/url_utility';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
  PIPELINE_EXECUTION_FILTER_OPTION,
} from 'ee/security_orchestration/components/policies/constants';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';
import { mockScanExecutionPoliciesResponse } from '../../mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from '../../mocks/mock_scan_result_policy_data';

Vue.use(VueApollo);

const namespacePath = 'path/to/project/or/group';

describe('List component', () => {
  let wrapper;

  const factory = (mountFn = mountExtended) => ({ props = {}, provide = {} } = {}) => {
    wrapper = mountFn(ListComponent, {
      propsData: {
        pipelineExecutionPolicies: mockPipelineExecutionPoliciesResponse,
        scanExecutionPolicies: mockScanExecutionPoliciesResponse,
        scanResultPolicies: mockScanResultPoliciesResponse,
        ...props,
      },
      provide: {
        disableScanPolicyUpdate: false,
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
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

    it("sets table's loading state", () => {
      mountShallowWrapper({ props: { isLoadingPolicies: true } });

      expect(findPoliciesTable().attributes('busy')).toBe('true');
    });
  });

  describe('given policies have been fetched', () => {
    let rows;

    beforeEach(() => {
      mountWrapper();
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

    it('updates url when type filter is selected', () => {
      findPolicyTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()}`,
        replace: true,
      });
    });
  });

  describe('selected policy', () => {
    beforeEach(() => {
      mountWrapper();
    });

    it('updates the selected policy when `shouldUpdatePolicyList` changes to `true`', async () => {
      findPoliciesTable().vm.$emit('row-selected', [mockScanExecutionPoliciesResponse[0]]);
      await nextTick();
      expect(findPolicyDrawer().props('policy')).toEqual(mockScanExecutionPoliciesResponse[0]);
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(findPolicyDrawer().props('policy')).toEqual(null);
    });

    it('does not update the selected policy when `shouldUpdatePolicyList` changes to `false`', async () => {
      expect(findPolicyDrawer().props('policy')).toEqual(null);
      wrapper.setProps({ shouldUpdatePolicyList: false });
      await nextTick();
      expect(findPolicyDrawer().props('policy')).toEqual(null);
    });
  });

  describe('status column', () => {
    beforeEach(() => {
      mountWrapper();
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
    it('renders when the policy is not inherited', () => {
      mountWrapper();
      expect(findPolicySourceCells().at(0).text()).toBe('This project');
    });

    it('renders when the policy is inherited', () => {
      mountWrapper();
      expect(trimText(findPolicySourceCells().at(1).text())).toBe(
        'Inherited from parent-group-name',
      );
    });

    it('renders inherited policy without namespace', () => {
      mountWrapper({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
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
      mountWrapper();
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

      mountWrapper();
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
    beforeEach(() => {
      mountWrapper({
        props: {
          scanExecutionPolicies: [mockScanExecutionPoliciesResponse[1]],
          scanResultPolicies: [mockScanResultPoliciesResponse[1]],
        },
      });
      findPolicySourceFilter().vm.$emit('input', POLICY_SOURCE_OPTIONS.INHERITED.value);
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
      value
      ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}
      ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}
    `('should select type filter value $value parameters are in url', ({ value }) => {
      jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(value);
      mountWrapper();
      expect(findPolicySourceFilter().props('value')).toBe(POLICY_SOURCE_OPTIONS.ALL.value);
      expect(findPolicyTypeFilter().props('value')).toBe(value);
    });

    it.each`
      value
      ${POLICY_SOURCE_OPTIONS.DIRECT.value}
      ${POLICY_SOURCE_OPTIONS.INHERITED.value}
    `('should select source filter value $value when parameters are in url', ({ value }) => {
      mountWrapper({ props: { selectedPolicySource: value } });
      expect(findPolicySourceFilter().props('value')).toBe(value);
      expect(findPolicyTypeFilter().props('value')).toBe(POLICY_TYPE_FILTER_OPTIONS.ALL.value);
    });
  });

  describe('scope column', () => {
    it.each([NAMESPACE_TYPES.GROUP, NAMESPACE_TYPES.PROJECT])(
      'renders policy scope column inside table on %s level',
      (namespaceType) => {
        mountWrapper({ provide: { namespaceType } });
        expect(findPolicyScopeCells()).toHaveLength(4);
        expect(findListComponentScope().exists()).toBe(true);
      },
    );
  });

  describe('breaking changes icon', () => {
    it('does not render breaking changes icon when flag is disabled', () => {
      mountWrapper();
      const icons = findPolicyStatusCells().at(0).findAll('svg');
      expect(icons.length).toBe(1);
      expect(icons.at(0).props('name')).toBe('check-circle-filled');
    });

    it('does not render breaking changes icon when there are no deprecated properties', () => {
      mountWrapper();
      const icons = findPolicyStatusCells().at(0).findAll('svg');
      expect(icons.length).toBe(1);
      expect(icons.at(0).props('name')).toBe('check-circle-filled');
    });

    it('renders breaking changes icon when there are deprecated properties', () => {
      mountWrapper({
        props: {
          scanResultPolicies: [
            { ...mockScanResultPoliciesResponse[0], deprecatedProperties: ['test', 'test1'] },
          ],
        },
      });
      const icon = findPolicyStatusCells().at(2).find('svg');
      expect(icon.props('name')).toBe('warning');
    });
  });

  describe('pipeline execution filter option', () => {
    beforeEach(() => {
      window.gon.features = { pipelineExecutionPolicyType: true };
    });

    it('updates url when type filter is selected', () => {
      mountWrapper({
        provide: {
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
  });
});
