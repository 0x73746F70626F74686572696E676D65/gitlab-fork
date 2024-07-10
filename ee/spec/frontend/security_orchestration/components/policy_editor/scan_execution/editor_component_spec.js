import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_execution/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/rule_section.vue';
import ActionBuilder from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_action.vue';
import OverloadWarningModal from 'ee/security_orchestration/components/policy_editor/scan_execution/overload_warning_modal.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE,
  SCAN_EXECUTION_DEFAULT_POLICY,
  ASSIGNED_POLICY_PROJECT,
  NEW_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  buildScannerAction,
  buildDefaultScheduleRule,
  fromYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { visitUrl } from '~/lib/utils/url_utility';

import { modifyPolicy } from 'ee/security_orchestration/components/policy_editor/utils';
import {
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_SCANNER,
  SCAN_EXECUTION_PIPELINE_RULE,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  RUNNER_TAGS_PARSING_ERROR,
  DAST_SCANNERS_PARSING_ERROR,
  EXECUTE_YAML_ACTION,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { RULE_KEY_MAP } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';

jest.mock('lodash/uniqueId');

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

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

  const mockCountResponse = (count = 0) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '1',
          projects: {
            count,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    return createMockApollo([[getGroupProjectsCount, handler]]);
  };

  const factory = ({
    propsData = {},
    provide = {},
    glFeatures = {},
    handler = mockCountResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.GROUP,
        scanPolicyDocumentationPath,
        customCiToggleEnabled: true,
        glFeatures,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, glFeatures = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockDastScanExecutionObject, ...policy },
        isEditing: true,
      },
      glFeatures,
    });
  };

  const findAddActionButton = () => wrapper.findByTestId('add-action');
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionBuilder = () => wrapper.findComponent(ActionBuilder);
  const findAllActionBuilders = () => wrapper.findAllComponents(ActionBuilder);
  const findRuleSection = () => wrapper.findComponent(RuleSection);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findAllActionSections = () => wrapper.findAllComponents(ActionSection);
  const findOverloadWarningModal = () => wrapper.findComponent(OverloadWarningModal);

  const selectScheduleRule = async () => {
    await findRuleSection().vm.$emit('changed', buildDefaultScheduleRule());
  };

  beforeEach(() => {
    uniqueId.mockImplementation(jest.fn((prefix) => `${prefix}0`));
  });

  describe('default', () => {
    beforeEach(() => {
      factory();
    });
    describe('policy scope', () => {
      it.each`
        namespaceType              | manifest
        ${NAMESPACE_TYPES.GROUP}   | ${SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE}
        ${NAMESPACE_TYPES.PROJECT} | ${SCAN_EXECUTION_DEFAULT_POLICY}
      `('should render default policy for a $namespaceType', ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });
        expect(findPolicyEditorLayout().props('policy')).toEqual(manifest);
      });
    });

    it('should render correctly', () => {
      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
      });
    });
  });

  describe('saving a policy', () => {
    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue                             | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE} | ${NEW_POLICY_PROJECT}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}            | ${ASSIGNED_POLICY_PROJECT}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}            | ${ASSIGNED_POLICY_PROJECT}
    `(
      'navigates to the new merge request when "modifyPolicy" is emitted $status',
      async ({ action, event, factoryFn, yamlEditorValue, currentlyAssignedPolicyProject }) => {
        factoryFn();
        findPolicyEditorLayout().vm.$emit(event);
        await waitForPromises();
        expect(modifyPolicy).toHaveBeenCalledTimes(1);
        expect(modifyPolicy).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: currentlyAssignedPolicyProject,
          name:
            action === SECURITY_POLICY_ACTIONS.APPEND
              ? fromYaml({ manifest: yamlEditorValue }).name
              : mockDastScanExecutionObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue,
        });
        expect(visitUrl).toHaveBeenCalledWith(
          `/${currentlyAssignedPolicyProject.fullPath}/-/merge_requests/2`,
        );
      },
    );
  });

  describe('when a user is not an owner of the project', () => {
    it('displays the empty state with the appropriate properties', async () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      await nextTick();
      const emptyState = findEmptyState();

      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('scan-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('modifying a policy', () => {
    beforeEach(factory);

    it('updates the yaml and policy object when "update-yaml" is emitted', async () => {
      const newManifest = `name: test
enabled: true`;

      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
        policy: fromYaml({ manifest: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE }),
        yamlEditorValue: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
      });
      findPolicyEditorLayout().vm.$emit('update-yaml', newManifest);
      await nextTick();
      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
        policy: expect.objectContaining({ enabled: true }),
        yamlEditorValue: newManifest,
      });
    });

    describe('properties', () => {
      it.each`
        component        | oldValue | newValue
        ${'name'}        | ${''}    | ${'new policy name'}
        ${'description'} | ${''}    | ${'new description'}
        ${'enabled'}     | ${true}  | ${false}
      `('updates the $component property', async ({ component, newValue, oldValue }) => {
        expect(findPolicyEditorLayout().props('policy')[component]).toBe(oldValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${oldValue}`,
        );

        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        await nextTick();

        expect(findPolicyEditorLayout().props('policy')[component]).toBe(newValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${newValue}`,
        );
      });

      it('removes the policy scope property', async () => {
        const oldValue = {
          policy_scope: { compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] },
        };

        factoryWithExistingPolicy({ policy: oldValue });
        expect(findPolicyEditorLayout().props('policy').policy_scope).toEqual(
          oldValue.policy_scope,
        );
        await findPolicyEditorLayout().vm.$emit('remove-property', 'policy_scope');
        expect(findPolicyEditorLayout().props('policy').policy_scope).toBe(undefined);
      });
    });
  });

  describe('policy rule builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
      factory();
    });

    it('should add new rule', async () => {
      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(initialValue);
      expect(findAllRuleSections()).toHaveLength(1);

      findAddRuleButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
      ];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(finalValue);
      expect(findAllRuleSections()).toHaveLength(2);
    });

    it('should update rule', async () => {
      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(initialValue);

      const finalValue = [{ ...RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](), branches: ['main'] }];
      findRuleSection().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(finalValue);
    });

    it('should remove rule', async () => {
      findAddRuleButton().vm.$emit('click');
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(2);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toHaveLength(2);

      findRuleSection().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(1);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toHaveLength(1);
    });
  });

  describe('policy action builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
      factory();
    });

    it('should add new action', async () => {
      const initialValue = [buildScannerAction({ scanner: DEFAULT_SCANNER })];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(initialValue);

      findAddActionButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        buildScannerAction({ scanner: DEFAULT_SCANNER }),
        buildScannerAction({ scanner: DEFAULT_SCANNER }),
      ];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should update action', async () => {
      const initialValue = [buildScannerAction({ scanner: DEFAULT_SCANNER })];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(initialValue);

      const finalValue = [buildScannerAction({ scanner: 'sast' })];
      findActionBuilder().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should remove action', async () => {
      findAddActionButton().vm.$emit('click');
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(2);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toHaveLength(2);

      findActionBuilder().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(1);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toHaveLength(1);
    });
  });

  describe('parsing tags errors', () => {
    beforeEach(() => {
      factory();
    });

    it.each`
      name               | errorKey                                         | expectedErrorMessage
      ${'tags'}          | ${POLICY_ACTION_BUILDER_TAGS_ERROR_KEY}          | ${RUNNER_TAGS_PARSING_ERROR}
      ${'DAST profiles'} | ${POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY} | ${DAST_SCANNERS_PARSING_ERROR}
    `(
      'disables rule editor when parsing of $name fails',
      async ({ errorKey, expectedErrorMessage }) => {
        findActionBuilder().vm.$emit('parsing-error', errorKey);
        await nextTick();
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(true);
        expect(findPolicyEditorLayout().props('parsingError')).toBe(expectedErrorMessage);
      },
    );
  });

  describe('execute yaml block section', () => {
    it.each`
      compliancePipelineInPolicies | customCiToggleEnabled | output
      ${true}                      | ${true}               | ${true}
      ${true}                      | ${false}              | ${false}
      ${false}                     | ${true}               | ${false}
      ${false}                     | ${false}              | ${false}
    `(
      'should render the correct action builder when compliancePipelineInPolicies is $compliancePipelineInPolicies and  customCiToggleEnabled is $customCiToggleEnabled',
      ({ compliancePipelineInPolicies, customCiToggleEnabled, output }) => {
        factory({
          provide: {
            glFeatures: { compliancePipelineInPolicies },
            customCiToggleEnabled,
          },
        });

        expect(findActionSection().exists()).toBe(output);
        expect(findScanFilterSelector().exists()).toBe(output);
        expect(findAddActionButton().exists()).toBe(!output);
      },
    );

    it('should add custom action', async () => {
      uniqueId.mockRestore();
      factory({
        provide: {
          glFeatures: { compliancePipelineInPolicies: true },
          customCiToggleEnabled: true,
        },
      });

      expect(findAllActionSections()).toHaveLength(1);

      await findScanFilterSelector().vm.$emit('select', EXECUTE_YAML_ACTION);

      expect(findAllActionSections()).toHaveLength(2);
    });
  });

  describe('performance warning modal', () => {
    describe('group', () => {
      describe('performance threshold not reached', () => {
        beforeEach(() => {
          factory();
        });

        it('saves policy when performance threshold is not reached', async () => {
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(modifyPolicy).toHaveBeenCalled();
        });

        it('saves policy when performance threshold is not reached and schedule rule is selected', async () => {
          await selectScheduleRule();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(modifyPolicy).toHaveBeenCalled();
        });
      });

      it('does not show the warning when performance threshold is reached but no schedule rules were selected', async () => {
        factory({
          handler: mockCountResponse(1001),
        });
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(modifyPolicy).toHaveBeenCalled();
      });

      describe('performance threshold reached', () => {
        beforeEach(async () => {
          factory({
            handler: mockCountResponse(1001),
          });

          await waitForPromises();
        });

        it('shows the warning when performance threshold is reached but schedule rules were selected', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(modifyPolicy).toHaveBeenCalledTimes(0);
        });

        it('dismisses the warning without saving the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(modifyPolicy).toHaveBeenCalledTimes(0);

          await findOverloadWarningModal().vm.$emit('cancel-submit');

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(modifyPolicy).toHaveBeenCalledTimes(0);
        });

        it('dismisses the warning and save the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(modifyPolicy).toHaveBeenCalledTimes(0);

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(modifyPolicy).toHaveBeenCalledTimes(1);
        });

        it('also shows warning modal in yaml mode', async () => {
          await selectScheduleRule();
          await waitForPromises();

          await findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_YAML);
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(modifyPolicy).toHaveBeenCalledTimes(0);
        });
      });
    });

    describe('project', () => {
      beforeEach(async () => {
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
          },
          handler: mockCountResponse(1001),
        });

        await waitForPromises();
      });

      it('does not show the warning when performance threshold is reached but schedule rules were selected for a project', async () => {
        await selectScheduleRule();
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(modifyPolicy).toHaveBeenCalledTimes(1);
      });
    });
  });
});
