import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable } from '@gitlab/ui';

import PoliciesSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/policies_section.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';

import complianceFrameworkPoliciesQuery from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/graphql/compliance_frameworks_policies.query.graphql';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const pageInfo = (endCursor) => ({
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'MQ',
  endCursor,
  __typename: 'PageInfo',
});

const editPath = (name) => `http://fake-path/edit/${name}`;
const makePolicy = ({ name, enabled, description, __typename, ...rest }) => ({
  name,
  enabled,
  description,
  yaml: '',
  editPath: editPath(name),
  source: {
    inherited: false,
    namespace: {
      id: '1',
      fullPath: '',
      name,
    },
  },
  updatedAt: Date.now(),
  userApprovers: [],
  allGroupApprovers: [],
  roleApprovers: [],
  __typename,
  ...rest,
});

const makeFakeResponse = () => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/29',
      approvalPolicies: {
        nodes: [
          makePolicy({
            name: 'test',
            enabled: false,
            description: 'Test1',
            __typename: 'ApprovalPolicy',
          }),
          makePolicy({
            name: 'test2',
            enabled: true,
            description: 'Test2',
            __typename: 'ApprovalPolicy',
          }),
        ],
        pageInfo: pageInfo('A1'),
        __typename: 'ApprovalPolicyConnection',
      },
      scanExecutionPolicies: {
        nodes: [
          makePolicy({
            name: 'testE',
            enabled: false,
            description: 'E1',
            __typename: 'ScanExecutionPolicy',
          }),
          makePolicy({
            name: 'testE2',
            enabled: true,
            description: 'E2',
            __typename: 'ScanExecutionPolicy',
          }),
        ],
        pageInfo: pageInfo('SE1'),
        __typename: 'ScanExecutionPolicyConnection',
      },
      complianceFrameworks: {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Framework/7',
            name: 'ddd',
            scanResultPolicies: {
              nodes: [{ name: 'test', __typename: 'ScanResultPolicy' }],
              pageInfo: pageInfo('A2'),
              __typename: 'ScanResultPolicyConnection',
            },
            scanExecutionPolicies: {
              nodes: [{ name: 'testE2', __typename: 'ScanExecutionPolicy' }],
              pageInfo: pageInfo('SE2'),
              __typename: 'ScanExecutionPolicyConnection',
            },
            __typename: 'ComplianceFramework',
          },
        ],
        __typename: 'ComplianceFrameworkConnection',
      },
      __typename: 'Namespace',
    },
  },
});

describe('Basic information section', () => {
  let wrapper;

  function createComponent({ requestHandlers = [], provide } = {}) {
    return mountExtended(PoliciesSection, {
      apolloProvider: createMockApollo(requestHandlers),
      provide: {
        disableScanPolicyUpdate: false,
        ...provide,
      },
      stubs: {
        DrawerWrapper: true,
      },
      propsData: {
        fullPath: 'Commit451',
        graphqlId: 'gid://gitlab/ComplianceManagement::Framework/1',
      },
    });
  }

  describe('when multiple pages are present', () => {
    let loadHandler;

    beforeEach(() => {
      const responseWithNextPages = makeFakeResponse();
      responseWithNextPages.data.namespace.approvalPolicies.pageInfo.hasNextPage = true;

      loadHandler = jest
        .fn()
        .mockResolvedValueOnce(responseWithNextPages)
        .mockResolvedValueOnce(makeFakeResponse());

      wrapper = createComponent({
        requestHandlers: [[complianceFrameworkPoliciesQuery, loadHandler]],
      });
    });

    it('loads next pages with appropriate cursors if has next pages', async () => {
      await waitForPromises();
      expect(loadHandler).toHaveBeenCalledWith({
        approvalPoliciesGlobalAfter: 'A1',
        approvalPoliciesAfter: 'A2',

        scanExecutionPoliciesGlobalAfter: 'SE1',
        scanExecutionPoliciesAfter: 'SE2',
        complianceFramework: 'gid://gitlab/ComplianceManagement::Framework/1',
        fullPath: 'Commit451',
      });
    });

    it('correctly stops loading next pages', async () => {
      await waitForPromises();
      await waitForPromises();
      expect(loadHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('when loaded', () => {
    beforeEach(() => {
      wrapper = createComponent({
        requestHandlers: [
          [complianceFrameworkPoliciesQuery, jest.fn().mockResolvedValue(makeFakeResponse())],
        ],
      });

      return waitForPromises();
    });

    it('correctly displays title', () => {
      expect(wrapper.text()).toContain('2 linked policies. Total policies in the group: 4');
    });

    it('correctly calculates policies', () => {
      const { items: policies } = wrapper.findComponent(GlTable).vm.$attrs;
      expect(policies).toHaveLength(4);
      expect(policies.find((p) => p.name === 'test').isLinked).toBe(true);
      expect(policies.find((p) => p.name === 'test2').isLinked).toBe(false);
      expect(policies.find((p) => p.name === 'testE').isLinked).toBe(false);
      expect(policies.find((p) => p.name === 'testE2').isLinked).toBe(true);
    });

    it('displays disabled badge for disabled policy', () => {
      const disabledBadge = wrapper.findByText('Disabled');
      expect(disabledBadge.element.closest('tr').textContent).toContain('Test1');
    });

    it('correctly renders linked checkboxes', () => {
      const checkboxes = wrapper.findAll('input[type="checkbox"]');
      expect(checkboxes.wrappers.map((c) => c.element.checked)).toStrictEqual([
        true,
        false,
        false,
        true,
      ]);
    });

    it('renders link to edit policy', () => {
      const { items: policies } = wrapper.findComponent(GlTable).vm.$attrs;
      const policyLink = wrapper.find('table tbody a');
      expect(policyLink.attributes('href')).toBe(editPath(policies[0].name));
    });

    describe('Drawer', () => {
      it('renders with selected policy', async () => {
        const drawer = wrapper.findComponent(DrawerWrapper);
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(drawer.props('policyType')).toBe('approval');
        expect(drawer.props('policy').name).toBe('test');
      });

      it('deselects policy when drawer generates close event', async () => {
        const drawer = wrapper.findComponent(DrawerWrapper);
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(drawer.props('policy').name).toBe('test');
        drawer.vm.$emit('close');
        await nextTick();
        expect(drawer.props('policy')).toBe(null);
      });
    });
  });
});
