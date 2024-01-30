import { GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import {
  SCAN_FINDING,
  ANY_MERGE_REQUEST,
  DEFAULT_PROJECT_SCAN_RESULT_POLICY,
  DEFAULT_GROUP_SCAN_RESULT_POLICY,
  getInvalidBranches,
  fromYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
  USER_TYPE,
} from 'ee/security_orchestration/constants';
import {
  mockForcePushSettingsManifest,
  mockBlockAndForceSettingsManifest,
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockDeprecatedScanResultManifest,
  mockDeprecatedScanResultObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import { unsupportedManifest } from 'ee_jest/security_orchestration/mocks/mock_data';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  PERMITTED_INVALID_SETTINGS,
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  pushingBranchesConfiguration,
  mergeRequestConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';

import { modifyPolicy } from 'ee/security_orchestration/components/policy_editor/utils';
import {
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  PARSING_ERROR_MESSAGE,
} from 'ee/security_orchestration/components/policy_editor/constants';
import DimDisableContainer from 'ee/security_orchestration/components/policy_editor/dim_disable_container.vue';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_result/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/rule_section.vue';

jest.mock('lodash/uniqueId');

jest.mock('ee/security_orchestration/components/policy_editor/scan_result/lib', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/scan_result/lib'),
  getInvalidBranches: jest.fn().mockResolvedValue([]),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const newlyCreatedPolicyProject = {
  branch: 'main',
  fullPath: 'path/to/new-project',
};
jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  assignSecurityPolicyProject: jest.fn().mockResolvedValue({
    branch: 'main',
    fullPath: 'path/to/new-project',
  }),
  modifyPolicy: jest.fn().mockResolvedValue({ id: '2' }),
}));

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';
  const assignedPolicyProject = {
    branch: 'main',
    fullPath: 'path/to/existing-project',
  };
  const scanResultPolicyApprovers = {
    user: [{ id: 1, username: 'the.one', state: 'active' }],
    group: [],
    role: [],
  };

  const factory = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespaceId: 1,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        scanPolicyDocumentationPath,
        scanResultPolicyApprovers,
        glFeatures,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({
    policy = {},
    provide = {},
    hasActions = true,
    glFeatures = {},
  } = {}) => {
    const existingPolicy = { ...mockDefaultBranchesScanResultObject };

    if (!hasActions) {
      delete existingPolicy.actions;
    }

    return factory({
      propsData: {
        assignedPolicyProject,
        existingPolicy: { ...existingPolicy, ...policy },
        isEditing: true,
      },
      provide,
      glFeatures,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findAllActionSections = () => wrapper.findAllComponents(ActionSection);
  const findAddActionButton = () => wrapper.findByTestId('add-action');
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findAllDisabledComponents = () => wrapper.findAllComponents(DimDisableContainer);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findEmptyActionsAlert = () => wrapper.findByTestId('empty-actions-alert');

  const changesToRuleMode = () =>
    findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_RULE);

  const changesToYamlMode = () =>
    findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_YAML);

  const verifiesParsingError = () => {
    expect(findPolicyEditorLayout().props('hasParsingError')).toBe(true);
    expect(findPolicyEditorLayout().attributes('parsingerror')).toBe(PARSING_ERROR_MESSAGE);
  };

  beforeEach(() => {
    getInvalidBranches.mockClear();
    uniqueId.mockImplementation(jest.fn((prefix) => `${prefix}0`));
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('rendering', () => {
    it('passes the default yamlEditorValue prop to the PolicyEditorLayout component', () => {
      factory();
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(mockForcePushSettingsManifest);
    });

    describe('feature flags', () => {
      describe('when the "scanResultPoliciesBlockUnprotectingBranches" feature flag is enabled', () => {
        it('passes the correct yamlEditorValue prop to the PolicyEditorLayout component', () => {
          factory({
            glFeatures: {
              scanResultPoliciesBlockUnprotectingBranches: true,
            },
          });
          expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
            mockBlockAndForceSettingsManifest,
          );
        });
      });
    });

    it.each`
      prop                 | compareFn          | expected
      ${'yamlEditorValue'} | ${'toBe'}          | ${DEFAULT_PROJECT_SCAN_RESULT_POLICY}
      ${'hasParsingError'} | ${'toBe'}          | ${false}
      ${'policy'}          | ${'toStrictEqual'} | ${fromYaml({ manifest: DEFAULT_PROJECT_SCAN_RESULT_POLICY })}
    `(
      'passes the correct $prop prop to the PolicyEditorLayout component',
      ({ prop, compareFn, expected }) => {
        uniqueId.mockRestore();
        factory();
        expect(findPolicyEditorLayout().props(prop))[compareFn](expected);
      },
    );

    it('displays the initial rule and add rule button', () => {
      factory();
      expect(findAllRuleSections()).toHaveLength(1);
      expect(findAddRuleButton().exists()).toBe(true);
    });

    it('displays the initial action', () => {
      factory();
      expect(findAllActionSections()).toHaveLength(1);
      expect(findActionSection().props('existingApprovers')).toEqual(scanResultPolicyApprovers);
    });

    describe('when a user is not an owner of the project', () => {
      it('displays the empty state with the appropriate properties', () => {
        factory({ provide: { disableScanPolicyUpdate: true } });

        const emptyState = findEmptyState();

        expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
        expect(emptyState.props('primaryButtonLink')).toMatch('scan-result-policy-editor');
        expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
      });
    });

    describe('existing policy', () => {
      it('displays an approval policy', () => {
        factoryWithExistingPolicy();
        expect(findEmptyActionsAlert().exists()).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDefaultBranchesScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
      });

      it('displays a scan result policy', () => {
        factoryWithExistingPolicy({ policy: mockDeprecatedScanResultObject });
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDeprecatedScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
      });
    });
  });

  describe('rule mode updates', () => {
    it.each`
      component        | oldValue | newValue
      ${'name'}        | ${''}    | ${'new policy name'}
      ${'description'} | ${''}    | ${'new description'}
      ${'enabled'}     | ${true}  | ${false}
    `('triggers a change on $component', ({ component, newValue, oldValue }) => {
      factory();
      expect(findPolicyEditorLayout().props('policy')[component]).toBe(oldValue);
      findPolicyEditorLayout().vm.$emit('set-policy-property', component, newValue);
      expect(findPolicyEditorLayout().props('policy')[component]).toBe(newValue);
    });

    describe('rule section', () => {
      it('adds a new rule', async () => {
        const rulesCount = 1;
        factory();
        expect(findAllRuleSections()).toHaveLength(rulesCount);
        await findAddRuleButton().vm.$emit('click');
        expect(findAllRuleSections()).toHaveLength(rulesCount + 1);
      });

      it('hides add button when the limit of five rules has been reached', () => {
        const limit = 5;
        const { id, ...rule } = mockDefaultBranchesScanResultObject.rules[0];
        uniqueId.mockRestore();
        factoryWithExistingPolicy({ policy: { rules: [rule, rule, rule, rule, rule] } });
        expect(findAllRuleSections()).toHaveLength(limit);
        expect(findAddRuleButton().exists()).toBe(false);
      });

      it('updates an existing rule', () => {
        const newValue = {
          type: 'scan_finding',
          branches: [],
          scanners: [],
          vulnerabilities_allowed: 1,
          severity_levels: [],
          vulnerability_states: [],
        };
        factory();

        findAllRuleSections().at(0).vm.$emit('changed', newValue);

        expect(wrapper.vm.policy.rules[0]).toEqual(newValue);
        expect(findPolicyEditorLayout().props('policy').rules[0].vulnerabilities_allowed).toBe(1);
      });

      it('deletes the initial rule', async () => {
        const initialRuleCount = 1;
        factory();

        expect(findAllRuleSections()).toHaveLength(initialRuleCount);

        await findAllRuleSections().at(0).vm.$emit('remove', 0);

        expect(findAllRuleSections()).toHaveLength(initialRuleCount - 1);
      });

      describe('settings', () => {
        const defaultProjectApprovalConfiguration = {
          [BLOCK_BRANCH_MODIFICATION]: true,
          [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
        };

        it('does update the settings containing permitted invalid settings', () => {
          factoryWithExistingPolicy({
            policy: { approval_settings: PERMITTED_INVALID_SETTINGS },
          });
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({ approval_settings: PERMITTED_INVALID_SETTINGS }),
          );
          findAllRuleSections().at(0).vm.$emit('changed', { type: SCAN_FINDING });
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: pushingBranchesConfiguration,
            }),
          );
        });

        it('does update the settings with the "scanResultPoliciesBlockUnprotectingBranches" ff enabled', () => {
          const features = {
            scanResultPoliciesBlockUnprotectingBranches: true,
          };
          window.gon = { features };
          const newValue = { type: ANY_MERGE_REQUEST };
          factory({ glFeatures: features });
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: defaultProjectApprovalConfiguration,
            }),
          );
          findAllRuleSections().at(0).vm.$emit('changed', newValue);
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: {
                ...defaultProjectApprovalConfiguration,
                ...mergeRequestConfiguration,
              },
            }),
          );
        });

        it('does update the settings containing permitted invalid values with the "scanResultPoliciesBlockUnprotectingBranches" ff enabled', () => {
          const features = {
            scanResultPoliciesBlockUnprotectingBranches: true,
          };
          window.gon = { features };
          factoryWithExistingPolicy({
            policy: { approval_settings: PERMITTED_INVALID_SETTINGS },
            glFeatures: features,
          });
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: PERMITTED_INVALID_SETTINGS,
            }),
          );
          findAllRuleSections().at(0).vm.$emit('changed', { type: SCAN_FINDING });
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: {
                ...pushingBranchesConfiguration,
                [BLOCK_BRANCH_MODIFICATION]: false,
              },
            }),
          );
        });

        it('does update the settings with ANY_MERGE_REQUEST type', () => {
          const newValue = { type: ANY_MERGE_REQUEST };
          factory();
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: { [PREVENT_PUSHING_AND_FORCE_PUSHING]: true },
            }),
          );
          findAllRuleSections().at(0).vm.$emit('changed', newValue);
          expect(findPolicyEditorLayout().props('policy')).toEqual(
            expect.objectContaining({
              approval_settings: {
                [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
                ...mergeRequestConfiguration,
              },
            }),
          );
        });
      });
    });

    describe('action section', () => {
      describe('add', () => {
        it('hides the add button when actions exist', () => {
          factory();
          expect(findActionSection().exists()).toBe(true);
          expect(findAddActionButton().exists()).toBe(false);
        });

        it('shows the add button when actions do not exist', () => {
          factoryWithExistingPolicy({ hasActions: false });
          expect(findActionSection().exists()).toBe(false);
          expect(findAddActionButton().exists()).toBe(true);
        });
      });

      describe('remove', () => {
        it('removes the initial action', async () => {
          factory();
          expect(findActionSection().exists()).toBe(true);
          expect(findPolicyEditorLayout().props('policy')).toHaveProperty('actions');
          await findActionSection().vm.$emit('remove');
          expect(findActionSection().exists()).toBe(false);
          expect(findPolicyEditorLayout().props('policy')).not.toHaveProperty('actions');
        });

        it('removes the action approvers when the action is removed', async () => {
          factory();
          await findActionSection().vm.$emit(
            'changed',
            mockDefaultBranchesScanResultObject.actions[0],
          );
          await findActionSection().vm.$emit('remove');
          await findAddActionButton().vm.$emit('click');
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            {
              approvals_required: 1,
              type: 'require_approval',
              id: 'action_0',
            },
          ]);
          expect(findActionSection().props('existingApprovers')).toEqual({});
        });
      });

      describe('update', () => {
        beforeEach(() => {
          factory();
        });

        it('updates policy action when edited', async () => {
          const UPDATED_ACTION = { type: 'required_approval', group_approvers_ids: [1] };
          await findActionSection().vm.$emit('changed', UPDATED_ACTION);

          expect(findActionSection().props('initAction')).toEqual(UPDATED_ACTION);
        });

        it('updates the policy approvers', async () => {
          const newApprover = ['owner'];

          await findActionSection().vm.$emit('updateApprovers', {
            ...scanResultPolicyApprovers,
            role: newApprover,
          });

          expect(findActionSection().props('existingApprovers')).toMatchObject({
            role: newApprover,
          });
        });

        it('creates an error when the action section emits one', async () => {
          await findActionSection().vm.$emit('error');
          verifiesParsingError();
        });
      });
    });
  });

  describe('yaml mode updates', () => {
    beforeEach(factory);

    it('updates the policy yaml and policy object when "update-yaml" is emitted', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDefaultBranchesScanResultManifest);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockDefaultBranchesScanResultManifest,
      );
      expect(findPolicyEditorLayout().props('policy')).toMatchObject(
        mockDefaultBranchesScanResultObject,
      );
    });

    it('disables all rule mode related components when the yaml is invalid', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', unsupportedManifest);

      expect(findAllDisabledComponents().at(0).props('disabled')).toBe(true);
      expect(findAllDisabledComponents().at(1).props('disabled')).toBe(true);
    });
  });

  describe('CRUD operations', () => {
    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue                          | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_PROJECT_SCAN_RESULT_POLICY}    | ${newlyCreatedPolicyProject}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifest} | ${assignedPolicyProject}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifest} | ${assignedPolicyProject}
    `(
      'navigates to the new merge request when "modifyPolicy" is emitted $status',
      async ({ action, event, factoryFn, yamlEditorValue, currentlyAssignedPolicyProject }) => {
        factoryFn();

        findPolicyEditorLayout().vm.$emit(event);
        await waitForPromises();

        expect(modifyPolicy).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: currentlyAssignedPolicyProject,
          name:
            action === SECURITY_POLICY_ACTIONS.APPEND
              ? fromYaml({ manifest: yamlEditorValue }).name
              : mockDefaultBranchesScanResultObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue,
        });
        expect(visitUrl).toHaveBeenCalledWith(
          `/${currentlyAssignedPolicyProject.fullPath}/-/merge_requests/2`,
        );
      },
    );

    describe('error handling', () => {
      const createError = (cause) => ({ message: 'There was an error', cause });
      const approverCause = { field: 'approvers_ids' };
      const branchesCause = { field: 'branches' };
      const unknownCause = { field: 'unknown' };

      describe('when in rule mode', () => {
        it('passes errors with the cause of `approvers_ids` to the action section', async () => {
          const error = createError([approverCause]);
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual(error.cause);
          expect(wrapper.emitted('error')).toStrictEqual([['']]);
        });

        it('emits error with the cause of `branches`', async () => {
          const error = createError([branchesCause]);
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('emits error with an unknown cause', async () => {
          const error = createError([unknownCause]);
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('handles mixed errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([approverCause]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], ['There was an error']]);
        });
      });

      describe('when in yaml mode', () => {
        it('emits errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          modifyPolicy.mockRejectedValue(error);
          factory();
          changesToYamlMode();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });
      });
    });
  });

  describe('errors', () => {
    it('creates an error for invalid yaml', async () => {
      factory();

      await findPolicyEditorLayout().vm.$emit('update-yaml', 'invalid manifest');

      verifiesParsingError();
    });

    it('creates an error when policy scanners are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ scanners: ['cluster_image_scanning'] }] } });

      await changesToRuleMode();
      verifiesParsingError();
    });

    it('creates an error when policy severity_levels are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ severity_levels: ['non-existent'] }] } });

      await changesToRuleMode();
      verifiesParsingError();
    });

    it('creates an error when vulnerabilities_allowed are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ vulnerabilities_allowed: 'invalid' }] } });

      await changesToRuleMode();
      verifiesParsingError();
    });

    it('creates an error when vulnerability_states are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ vulnerability_states: ['invalid'] }] } });

      await changesToRuleMode();
      verifiesParsingError();
    });

    it('creates an error when vulnerability_age is invalid', async () => {
      factoryWithExistingPolicy({
        policy: { rules: [{ vulnerability_age: { operator: 'invalid' } }] },
      });

      await changesToRuleMode();
      verifiesParsingError();
    });

    it('creates an error when vulnerability_attributes are invalid', async () => {
      factoryWithExistingPolicy({
        policy: { rules: [{ vulnerability_attributes: [{ invalid: true }] }] },
      });

      await changesToRuleMode();
      verifiesParsingError();
    });

    describe('existing approvers', () => {
      const existingPolicyWithUserId = {
        actions: [{ type: 'require_approval', approvals_required: 1, user_approvers_ids: [1] }],
      };

      const existingUserApprover = {
        user: [{ id: 1, username: 'the.one', state: 'active', type: USER_TYPE }],
      };
      const nonExistingUserApprover = {
        user: [{ id: 2, username: 'the.two', state: 'active', type: USER_TYPE }],
      };

      it.each`
        title         | policy                      | approver                   | output
        ${'does not'} | ${{}}                       | ${existingUserApprover}    | ${false}
        ${'does'}     | ${{}}                       | ${nonExistingUserApprover} | ${true}
        ${'does not'} | ${existingPolicyWithUserId} | ${existingUserApprover}    | ${false}
        ${'does'}     | ${existingPolicyWithUserId} | ${nonExistingUserApprover} | ${true}
      `(
        '$title create an error when the policy does not match existing approvers',
        async ({ policy, approver, output }) => {
          factoryWithExistingPolicy({
            policy,
            provide: {
              scanResultPolicyApprovers: approver,
            },
          });

          await changesToRuleMode();
          expect(findPolicyEditorLayout().props('hasParsingError')).toBe(output);
        },
      );
    });
  });

  describe('branches being validated', () => {
    it.each`
      status                             | value       | errorMessage
      ${'invalid branches do not exist'} | ${[]}       | ${''}
      ${'invalid branches exist'}        | ${['main']} | ${'The following branches do not exist on this development project: main. Please review all protected branches to ensure the values are accurate before updating this policy.'}
    `(
      'triggers error event with the correct content when $status',
      async ({ value, errorMessage }) => {
        const rule = { ...mockDefaultBranchesScanResultObject.rules[0], branches: ['main'] };
        getInvalidBranches.mockReturnValue(value);

        factoryWithExistingPolicy({ policy: { rules: [rule] } });

        await findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_RULE);
        await waitForPromises();
        const errors = wrapper.emitted('error');

        expect(errors[errors.length - 1]).toEqual([errorMessage]);
      },
    );

    it('does not query protected branches when namespaceType is other than project', async () => {
      factoryWithExistingPolicy({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });

      await findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_RULE);
      await waitForPromises();

      expect(getInvalidBranches).not.toHaveBeenCalled();
    });
  });

  describe('policy scope', () => {
    it.each`
      securityPoliciesPolicyScope | namespaceType              | manifest
      ${true}                     | ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_GROUP_SCAN_RESULT_POLICY}
      ${false}                    | ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_PROJECT_SCAN_RESULT_POLICY}
      ${true}                     | ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_PROJECT_SCAN_RESULT_POLICY}
      ${false}                    | ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_PROJECT_SCAN_RESULT_POLICY}
    `(
      'should render default policy',
      ({ securityPoliciesPolicyScope, namespaceType, manifest }) => {
        const features = {
          securityPoliciesPolicyScope,
        };
        window.gon = { features };

        factory({
          glFeatures: features,
          provide: {
            namespaceType,
          },
        });

        expect(findPolicyEditorLayout().props('policy')).toEqual(fromYaml({ manifest }));
      },
    );
  });

  describe('settings section', () => {
    describe('settings', () => {
      describe('without default flags', () => {
        beforeEach(() => {
          factory();
        });

        it('displays setting section', () => {
          expect(findSettingsSection().exists()).toBe(true);
        });

        it('shows default settings for non-merge request rules', async () => {
          await findAllRuleSections().at(0).vm.$emit('changed', { type: 'scan_finding' });
          expect(findSettingsSection().exists()).toBe(true);
          expect(findSettingsSection().props('settings')).toEqual({
            [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
          });
        });

        it('does show the policy for merge request rule in addition to the default settings', async () => {
          await findAllRuleSections().at(0).vm.$emit('changed', { type: 'any_merge_request' });
          expect(findSettingsSection().props('settings')).toEqual({
            [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
            ...mergeRequestConfiguration,
          });
        });

        it('updates the policy for merge request rule', async () => {
          findAllRuleSections().at(0).vm.$emit('changed', { type: 'any_merge_request' });
          await findSettingsSection().vm.$emit('changed', {
            [PREVENT_APPROVAL_BY_AUTHOR]: false,
          });
          expect(findSettingsSection().props('settings')).toEqual({
            ...pushingBranchesConfiguration,
            ...mergeRequestConfiguration,
            [PREVENT_APPROVAL_BY_AUTHOR]: false,
          });
        });

        it('updates the policy when a change is emitted for pushingBranchesConfiguration', async () => {
          await findSettingsSection().vm.$emit('changed', {
            [PREVENT_PUSHING_AND_FORCE_PUSHING]: false,
          });
          expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
            `${PREVENT_PUSHING_AND_FORCE_PUSHING}: false`,
          );
        });
      });

      describe('with feature flags', () => {
        describe('with "scanResultPoliciesBlockUnprotectingBranches" feature flag enabled', () => {
          beforeEach(() => {
            const features = { scanResultPoliciesBlockUnprotectingBranches: true };
            window.gon = { features };
            factory({ glFeatures: features });
          });

          it('displays setting section', () => {
            expect(findSettingsSection().exists()).toBe(true);
            expect(findSettingsSection().props('settings')).toEqual({
              [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
              [BLOCK_BRANCH_MODIFICATION]: true,
            });
          });

          it('updates the policy when a change is emitted', async () => {
            await findSettingsSection().vm.$emit('changed', {
              [BLOCK_BRANCH_MODIFICATION]: false,
            });
            expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
              `${BLOCK_BRANCH_MODIFICATION}: false`,
            );
          });
        });
      });
    });

    describe('empty policy alert', () => {
      const features = { scanResultPoliciesBlockUnprotectingBranches: true };
      const policy = { approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } };
      describe('when there are actions and settings', () => {
        beforeEach(() => {
          window.gon = { features };
          factoryWithExistingPolicy({
            glFeatures: features,
            policy,
          });
        });

        it('does not display the alert', () => {
          expect(findEmptyActionsAlert().exists()).toBe(false);
        });

        it('does not disable the save button', () => {
          expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
        });
      });

      describe('when there are actions and no settings', () => {
        beforeEach(() => {
          factoryWithExistingPolicy();
        });

        it('does not display the alert', () => {
          expect(findEmptyActionsAlert().exists()).toBe(false);
        });

        it('does not disable the save button', () => {
          expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
        });
      });

      describe('when there are settings and no actions', () => {
        beforeEach(() => {
          window.gon = { features };
          factoryWithExistingPolicy({
            glFeatures: features,
            hasActions: false,
            policy,
          });
        });

        it('displays the alert', () => {
          expect(findEmptyActionsAlert().exists()).toBe(true);
          expect(findEmptyActionsAlert().props('variant')).toBe('warning');
        });

        it('does not disable the save button', () => {
          expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
        });
      });

      describe('displays the danger alert when there are no actions and no settings', () => {
        beforeEach(() => {
          window.gon = { features };
          factoryWithExistingPolicy({
            glFeatures: features,
            hasActions: false,
            policy: { approval_settings: { [BLOCK_BRANCH_MODIFICATION]: false } },
          });
        });

        it('displays the danger alert', () => {
          expect(findEmptyActionsAlert().exists()).toBe(true);
          expect(findEmptyActionsAlert().props('variant')).toBe('danger');
        });

        it('disabled the update button', () => {
          expect(findPolicyEditorLayout().props('disableUpdate')).toBe(true);
        });
      });

      describe('does not display the danger alert when the policy is invalid', () => {
        beforeEach(() => {
          factoryWithExistingPolicy({
            policy: { approval_settings: { invalid_setting: true } },
          });
        });

        it('displays the danger alert', () => {
          expect(findEmptyActionsAlert().exists()).toBe(false);
        });

        it('disabled the update button', () => {
          expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
        });
      });
    });
  });
});
