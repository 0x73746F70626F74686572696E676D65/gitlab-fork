import { convertToTitleCase } from '~/lib/utils/text_utility';
import DetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import ToggleList from 'ee/security_orchestration/components/policy_drawer/toggle_list.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import Approvals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import Settings from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_settings.vue';
import {
  disabledSendBotMessageActionScanResultManifest,
  enabledSendBotMessageActionScanResultManifest,
  mockProjectScanResultPolicy,
  mockProjectWithAllApproverTypesScanResultPolicy,
  mockApprovalSettingsScanResultPolicy,
  mockProjectFallbackClosedScanResultManifest,
  mockNoFallbackScanResultManifest,
  zeroActionsScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';

describe('DetailsDrawer component', () => {
  let wrapper;

  const findAdditionalDetails = () => wrapper.findByTestId('additional-details');
  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findPolicyApprovals = () => wrapper.findComponent(Approvals);
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findSettings = () => wrapper.findComponent(Settings);
  const findBotMessage = () => wrapper.findByTestId('policy-bot-message');

  const factory = ({ props } = {}) => {
    wrapper = shallowMountExtended(DetailsDrawer, {
      propsData: {
        policy: mockProjectScanResultPolicy,
        ...props,
      },
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the PolicyDrawerLayout component', () => {
      factory();
      expect(findPolicyDrawerLayout().props('policy')).toBe(mockProjectScanResultPolicy);
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      factory();
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces critical vulnerability CS approvals',
      );
    });
  });

  describe('summary', () => {
    it('renders the policy summary', () => {
      factory();
      expect(findSummary().exists()).toBe(true);
    });

    describe('settings', () => {
      it('passes the settings to the "Settings" component if settings are present', () => {
        factory({ props: { policy: mockApprovalSettingsScanResultPolicy } });
        expect(findSettings().props('settings')).toEqual(
          mockApprovalSettingsScanResultPolicy.approval_settings,
        );
      });

      it('passes the empty object to the "Settings" component if no settings are present', () => {
        factory();
        expect(findSettings().props('settings')).toEqual({});
      });
    });

    describe('approvals', () => {
      it('renders the "Approvals" component correctly', () => {
        factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
        expect(findPolicyApprovals().exists()).toBe(true);
        expect(findPolicyApprovals().props('approvers')).toStrictEqual([
          ...mockProjectWithAllApproverTypesScanResultPolicy.allGroupApprovers,
          ...mockProjectWithAllApproverTypesScanResultPolicy.roleApprovers.map((r) =>
            convertToTitleCase(r.toLowerCase()),
          ),
          ...mockProjectWithAllApproverTypesScanResultPolicy.userApprovers,
        ]);
      });

      it('should not render branch exceptions list without exceptions', () => {
        factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
        expect(findToggleList().exists()).toBe(false);
      });
    });

    describe('send bot message', () => {
      it('hides the text when it is disabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: disabledSendBotMessageActionScanResultManifest,
            },
          },
        });
        expect(findBotMessage().exists()).toBe(false);
      });

      it('shows the message when the action is not included', () => {
        factory({ props: { policy: mockProjectScanResultPolicy } });
        expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
      });

      it('shows the message when the action is enabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: enabledSendBotMessageActionScanResultManifest,
            },
          },
        });
        expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
      });

      it('shows the message when there are zero actions is enabled', () => {
        factory({
          props: {
            policy: {
              ...mockProjectWithAllApproverTypesScanResultPolicy,
              yaml: zeroActionsScanResultManifest,
            },
          },
        });
        expect(findBotMessage().exists()).toBe(true);
      });
    });
  });

  describe('fallback behavior', () => {
    it('does not render the fallback behavior section if the policy does not have the fallback behavior property', () => {
      factory({
        props: {
          policy: { ...mockProjectScanResultPolicy, yaml: mockNoFallbackScanResultManifest },
        },
      });
      expect(findAdditionalDetails().isVisible()).toBe(false);
      expect(findAdditionalDetails().text()).toBe('');
    });

    it('renders the open fallback behavior', () => {
      factory();
      expect(findAdditionalDetails().isVisible()).toBe(true);
      expect(findAdditionalDetails().text()).toBe(
        'Fail open: Allow the merge request to proceed, even if not all criteria are met',
      );
    });

    it('renders the closed fallback behavior', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: mockProjectFallbackClosedScanResultManifest,
          },
        },
      });
      expect(findAdditionalDetails().isVisible()).toBe(true);
      expect(findAdditionalDetails().text()).toBe(
        'Fail closed: Block the merge request until all criteria are met',
      );
    });
  });
});
