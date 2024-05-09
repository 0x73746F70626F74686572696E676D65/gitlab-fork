import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import DefaultRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/default_rule_builder.vue';
import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import AnyMergeRequestRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/any_merge_request_rule_builder.vue';
import LicenseScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_scan_rule_builder.vue';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/security_scan_rule_builder.vue';
import SettingsItem from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_item.vue';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import {
  ANY_MERGE_REQUEST,
  SCAN_FINDING,
  LICENSE_FINDING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify } from '../utils';
import {
  mockSecurityApprovalManifest,
  mockLicenseApprovalManifest,
  mockAnyMergeRequestApprovalManifest,
} from './mocks';

describe('Scan result policy rules', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
        scanResultPolicyApprovers: {},
      },
      stubs: {
        SourceEditor: true,
        SettingPopover: true,
      },
    });
  };

  beforeEach(() => {
    jest
      .spyOn(urlUtils, 'getParameterByName')
      .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter);
  });

  afterEach(() => {
    window.gon = {};
  });

  const findSecurityScanRuleBuilder = () => wrapper.findComponent(SecurityScanRuleBuilder);
  const findLicenseScanRuleBuilder = () => wrapper.findComponent(LicenseScanRuleBuilder);
  const findDefaultRuleBuilder = () => wrapper.findComponent(DefaultRuleBuilder);
  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);
  const findAnyMergeRequestRuleBuilder = () => wrapper.findComponent(AnyMergeRequestRuleBuilder);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findAllSettingsItem = () => wrapper.findAllComponents(SettingsItem);

  describe('security scan', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should select security scan rule', async () => {
      const verifyRuleMode = () => {
        expect(findDefaultRuleBuilder().exists()).toBe(false);
        expect(findSecurityScanRuleBuilder().exists()).toBe(true);
        expect(findSettingsSection().exists()).toBe(true);
      };

      await findScanTypeSelect().vm.$emit('select', SCAN_FINDING);
      await verify({
        manifest: mockSecurityApprovalManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('license rule', () => {
    const verifyRuleMode = () => {
      expect(findDefaultRuleBuilder().exists()).toBe(false);
      expect(findLicenseScanRuleBuilder().exists()).toBe(true);
      expect(findSettingsSection().exists()).toBe(true);
    };

    beforeEach(() => {
      createWrapper();
    });

    it('should select license rule', async () => {
      await findScanTypeSelect().vm.$emit('select', LICENSE_FINDING);
      await verify({ manifest: mockLicenseApprovalManifest, verifyRuleMode, wrapper });
    });

    it('should select license rule after breaking changes for match on inclusion license', async () => {
      await findScanTypeSelect().vm.$emit('select', LICENSE_FINDING);
      await verify({
        manifest: mockLicenseApprovalManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('any merge request rule', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should select any merge request rule', async () => {
      const verifyRuleMode = () => {
        expect(findDefaultRuleBuilder().exists()).toBe(false);
        expect(findAnyMergeRequestRuleBuilder().exists()).toBe(true);
        expect(findSettingsSection().exists()).toBe(true);
        expect(findAllSettingsItem()).toHaveLength(2);
      };

      await findScanTypeSelect().vm.$emit('select', ANY_MERGE_REQUEST);
      await verify({ manifest: mockAnyMergeRequestApprovalManifest, verifyRuleMode, wrapper });
    });
  });
});
