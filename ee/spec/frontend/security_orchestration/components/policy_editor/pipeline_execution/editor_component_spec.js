import { GlEmptyState } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/pipeline_execution/editor_component.vue';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import { DEFAULT_PIPELINE_EXECUTION_POLICY } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  modifyPolicy,
  doesFileExist,
} from 'ee/security_orchestration/components/policy_editor/utils';
import {
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';

import {
  ASSIGNED_POLICY_PROJECT,
  NEW_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  mockPipelineExecutionManifest,
  mockWithoutRefPipelineExecutionManifest,
  mockWithoutRefPipelineExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

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
  doesFileExist: jest.fn().mockResolvedValue({
    data: {
      project: {
        repository: {
          blobs: {
            nodes: [{ fileName: 'file ' }],
          },
        },
      },
    },
  }),
}));

describe('EditorComponent', () => {
  let wrapper;
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';
  const defaultProjectPath = 'path/to/project';

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        namespacePath: defaultProjectPath,
        policyEditorEmptyStateSvgPath,
        scanPolicyDocumentationPath,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, glFeatures = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockWithoutRefPipelineExecutionObject, ...policy },
        isEditing: true,
      },
      glFeatures,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findRuleSection = () => wrapper.findComponent(RuleSection);

  const changesToYamlMode = () =>
    findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_YAML);

  describe('rule mode', () => {
    it('renders the editor', () => {
      factory();
      expect(findPolicyEditorLayout().exists()).toBe(true);
      expect(findActionSection().exists()).toBe(true);
      expect(findRuleSection().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders the default policy editor layout', () => {
      factory();
      const editorLayout = findPolicyEditorLayout();
      expect(editorLayout.exists()).toBe(true);
      expect(editorLayout.props()).toEqual(
        expect.objectContaining({
          yamlEditorValue: DEFAULT_PIPELINE_EXECUTION_POLICY,
        }),
      );
    });

    it('updates the general policy properties', async () => {
      const name = 'New name';
      factory();
      expect(findPolicyEditorLayout().props('policy').name).toBe('');
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain("name: ''");
      await findPolicyEditorLayout().vm.$emit('update-property', 'name', name);
      expect(findPolicyEditorLayout().props('policy').name).toBe(name);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(`name: ${name}`);
    });
  });

  describe('yaml mode', () => {
    it('updates the policy', async () => {
      factory();
      await findPolicyEditorLayout().vm.$emit(
        'update-yaml',
        mockWithoutRefPipelineExecutionManifest,
      );
      expect(findPolicyEditorLayout().props('policy')).toEqual(
        mockWithoutRefPipelineExecutionObject,
      );
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockWithoutRefPipelineExecutionManifest,
      );
    });
  });

  describe('empty page', () => {
    it('renders', () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      expect(findPolicyEditorLayout().exists()).toBe(false);
      expect(findActionSection().exists()).toBe(false);
      expect(findRuleSection().exists()).toBe(false);

      const emptyState = findEmptyState();
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('pipeline-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('saving a policy', () => {
    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue                            | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_PIPELINE_EXECUTION_POLICY}       | ${NEW_POLICY_PROJECT}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockWithoutRefPipelineExecutionManifest} | ${ASSIGNED_POLICY_PROJECT}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockWithoutRefPipelineExecutionManifest} | ${ASSIGNED_POLICY_PROJECT}
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
              : mockWithoutRefPipelineExecutionObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue,
        });
        expect(visitUrl).toHaveBeenCalledWith(
          `/${currentlyAssignedPolicyProject.fullPath}/-/merge_requests/2`,
        );
      },
    );

    describe('error handling', () => {
      describe('when in rule mode', () => {
        it('clears the error message before making the network request', () => {
          const error = { message: 'There was a graphql error', cause: '' };
          modifyPolicy.mockRejectedValue(error);
          factory();
          findPolicyEditorLayout().vm.$emit('save-policy');
          expect(wrapper.emitted('error')).toStrictEqual([['']]);
        });

        it('passes graphql errors', async () => {
          const error = { message: 'There was a graphql error', cause: '' };
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();
          expect(wrapper.emitted('error')).toStrictEqual([
            [''],
            ['There was a problem creating the new security policy'],
          ]);
        });

        it('passes non-graphql errors', async () => {
          const error = { message: 'There was an error', cause: '' };
          modifyPolicy.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();
          expect(wrapper.emitted('error')).toStrictEqual([[''], ['There was an error']]);
        });

        it('sets the loading flag on error', async () => {
          const error = { message: 'There was an error', cause: '' };
          modifyPolicy.mockRejectedValue(error);
          factory();
          expect(findPolicyEditorLayout().props('isUpdatingPolicy')).toBe(false);
          await findPolicyEditorLayout().vm.$emit('save-policy');
          expect(findPolicyEditorLayout().props('isUpdatingPolicy')).toBe(true);
          await waitForPromises();
          expect(findPolicyEditorLayout().props('isUpdatingPolicy')).toBe(false);
        });
      });

      describe('when in yaml mode', () => {
        it('emits errors', async () => {
          const error = { message: 'There was an error', cause: '' };
          modifyPolicy.mockRejectedValue(error);
          factory();
          changesToYamlMode();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });
      });
    });
  });

  describe('action validation error', () => {
    describe('no validation', () => {
      it('does not validate on new linked file section', () => {
        factory();
        expect(doesFileExist).toHaveBeenCalledTimes(0);
        expect(findPolicyEditorLayout().props('disableUpdate')).toBe(true);
      });
    });

    describe('new policy', () => {
      beforeEach(async () => {
        factory();
        await findPolicyEditorLayout().vm.$emit('update-property', 'name', 'New name');
      });

      it.each`
        payload                                                                       | expectedResult
        ${{ include: [{ project: 'project-path' }] }}                                 | ${{ filePath: undefined, fullPath: 'project-path', ref: null }}
        ${{ include: [{ project: 'project-path', ref: 'main', file: 'file-name' }] }} | ${{ filePath: 'file-name', fullPath: 'project-path', ref: 'main' }}
      `('makes a call to validate the selection', async ({ payload, expectedResult }) => {
        expect(doesFileExist).toHaveBeenCalledTimes(0);

        await findActionSection().vm.$emit('set-ref', 'main');
        await findActionSection().vm.$emit('changed', 'content', payload);

        expect(doesFileExist).toHaveBeenCalledWith(expectedResult);
        expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
      });

      it('calls validation when switched to yaml mode', async () => {
        await changesToYamlMode();

        expect(doesFileExist).toHaveBeenCalledTimes(0);

        await findPolicyEditorLayout().vm.$emit('update-yaml', mockPipelineExecutionManifest);

        expect(doesFileExist).toHaveBeenCalledWith({
          filePath: 'test_path',
          fullPath: 'gitlab-policies/js6',
          ref: 'main',
        });
        expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
      });
    });

    describe('existing policy', () => {
      beforeEach(() => {
        mockWithoutRefPipelineExecutionObject.content.include[0].ref = 'main';
        factory({
          propsData: {
            existingPolicy: { ...mockWithoutRefPipelineExecutionObject },
          },
        });
      });
      it('validates on existing policy initial state', () => {
        expect(doesFileExist).toHaveBeenCalledWith({
          filePath: '.pipeline-execution.yml',
          fullPath: 'GitLab.org/GitLab',
          ref: 'main',
        });
      });

      it.each`
        payload                                                                       | expectedResult
        ${{ include: [{ project: 'project-path' }] }}                                 | ${{ filePath: undefined, fullPath: 'project-path', ref: null }}
        ${{ include: [{ project: 'project-path', ref: 'main', file: 'file-name' }] }} | ${{ filePath: 'file-name', fullPath: 'project-path', ref: 'main' }}
      `('makes a call to validate the selection', async ({ payload, expectedResult }) => {
        expect(doesFileExist).toHaveBeenCalledTimes(1);

        await findActionSection().vm.$emit('set-ref', 'main');
        await findActionSection().vm.$emit('changed', 'content', payload);

        expect(doesFileExist).toHaveBeenCalledWith(expectedResult);
        expect(findPolicyEditorLayout().props('disableUpdate')).toBe(false);
      });
    });
  });
});
