import {
  GlFormInput,
  GlSprintf,
  GlFormGroup,
  GlFormInputGroup,
  GlIcon,
  GlTruncate,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CodeBlockStrategySelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_strategy_selector.vue';
import CodeBlockSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_source_selector.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_file_path.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';
import RefSelector from '~/ref/components/ref_selector.vue';
import {
  INSERTED_CODE_BLOCK,
  INJECT,
  OVERRIDE,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('CodeBlockFilePath', () => {
  let wrapper;

  const PROJECT_ID = 'gid://gitlab/Project/29';

  const createComponent = ({ propsData = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(CodeBlockFilePath, {
      propsData: {
        selectedType: INSERTED_CODE_BLOCK,
        ...propsData,
      },
      stubs: {
        GlSprintf,
        ...stubs,
      },
      provide: {
        namespacePath: 'gitlab-org',
        namespaceType: NAMESPACE_TYPES.GROUP,
        rootNamespacePath: 'gitlab',
        ...provide,
      },
    });
  };

  const findCodeBlockSourceSelector = () => wrapper.findComponent(CodeBlockSourceSelector);
  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findFormInputGroup = () => wrapper.findComponent(GlFormInputGroup);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findStrategySelector = () => wrapper.findComponent(CodeBlockStrategySelector);
  const findRefSelector = () => wrapper.findComponent(RefSelector);
  const findPipelineExecutionRefSelector = () =>
    wrapper.findByTestId('pipeline-execution-ref-selector');
  const findTruncate = () => wrapper.findComponent(GlTruncate);

  describe('initial state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders file path', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormInputGroup().exists()).toBe(true);
      expect(findFormInputGroup().attributes().disabled).toBe('true');
      expect(findTruncate().props('text')).toBe('No project selected');
    });

    it('renders ref input', () => {
      expect(findFormInput().exists()).toBe(true);
    });

    it('renders projects dropdown', () => {
      expect(findGroupProjectsDropdown().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('multiple')).toBe(false);
    });

    it('renders action type selector on scan execution policy editor', () => {
      expect(findCodeBlockSourceSelector().exists()).toBe(true);
      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);
    });
  });

  describe('pipeline execution policy', () => {
    it('renders message for "inject" pipeline execution policy', () => {
      createComponent({
        propsData: { isPipelineExecution: true },
        stubs: { GlSprintf: false },
      });
      expect(findGlSprintf().attributes('message')).toBe(
        '%{strategySelector}into the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      );
    });

    it('renders message for "override" pipeline execution policy', () => {
      createComponent({
        propsData: { strategy: OVERRIDE, isPipelineExecution: true },
        stubs: { GlSprintf: false },
      });
      expect(findGlSprintf().attributes('message')).toBe(
        '%{strategySelector}the %{boldStart}.gitlab-ci.yml%{boldEnd} with the following %{boldStart}pipeline execution file%{boldEnd} from %{projectSelector}',
      );
    });

    it('renders icon tooltip message for inject pipeline execution policy', () => {
      createComponent({ propsData: { isPipelineExecution: true } });
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file is injected into the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      );
    });

    it('renders icon tooltip message for override pipeline execution policy', () => {
      createComponent({
        propsData: { strategy: OVERRIDE, isPipelineExecution: true },
      });
      expect(findIcon().attributes('title')).toBe(
        'The content of this pipeline execution YAML file overrides the .gitlab-ci.yml file of the target project. All GitLab CI/CD features are supported.',
      );
    });

    it('renders the help icon', () => {
      createComponent({ propsData: { isPipelineExecution: true } });
      expect(findIcon().exists()).toBe(true);
    });

    it('renders pipeline execution ref selector', () => {
      createComponent({
        propsData: { isPipelineExecution: true },
        stubs: { GlSprintf: false },
      });
      expect(findRefSelector().exists()).toBe(false);
      expect(findPipelineExecutionRefSelector().exists()).toBe(true);
    });
  });

  describe('selected state', () => {
    it('render selected ref input', () => {
      createComponent({
        propsData: {
          selectedRef: 'ref',
        },
      });

      expect(findRefSelector().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(true);
      expect(findFormInput().attributes('value')).toBe('ref');
    });

    it('renders selected project and ref selector on scan execution policy editor', () => {
      const fullPath = 'path/to/project';

      createComponent({
        propsData: {
          selectedProject: {
            id: PROJECT_ID,
            fullPath,
          },
          selectedRef: 'ref',
        },
      });

      expect(findTruncate().props('text')).toBe(fullPath);
      expect(findIcon().exists()).toBe(false);
      expect(findRefSelector().exists()).toBe(true);
      expect(findPipelineExecutionRefSelector().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(false);
      expect(findRefSelector().props()).toEqual(
        expect.objectContaining({
          translations: {
            noRefSelected: 'default branch',
          },
          value: 'ref',
        }),
      );
      expect(findGroupProjectsDropdown().props('selected')).toBe(PROJECT_ID);
      expect(findFormInputGroup().attributes().disabled).toBe(undefined);
      expect(findTruncate().props('text')).toBe(fullPath);
    });

    it('renders selected file path', () => {
      createComponent({
        propsData: {
          filePath: 'filePath',
        },
      });

      expect(findFormInputGroup().attributes('value')).toBe('filePath');
    });

    it('has fallback values', () => {
      createComponent({
        propsData: {
          selectedProject: {},
        },
      });

      expect(findRefSelector().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('selected')).toEqual([]);
    });

    it('renders selected override', () => {
      createComponent({
        propsData: { strategy: OVERRIDE, isPipelineExecution: true },
      });
      expect(findStrategySelector().props('strategy')).toBe(OVERRIDE);
    });
  });

  describe('actions', () => {
    it('can select ref', () => {
      createComponent();

      findFormInput().vm.$emit('input', 'ref');

      expect(wrapper.emitted('select-ref')).toEqual([['ref']]);
    });

    it('can select ref with selector', () => {
      createComponent({
        propsData: {
          selectedProject: {
            id: PROJECT_ID,
          },
        },
      });

      findRefSelector().vm.$emit('input', 'ref');

      expect(wrapper.emitted('select-ref')).toEqual([['ref']]);
    });

    it('can select project', () => {
      createComponent();

      findGroupProjectsDropdown().vm.$emit('select', PROJECT_ID);

      expect(wrapper.emitted('select-project')).toEqual([[PROJECT_ID]]);
    });

    it('can select file path', () => {
      createComponent();

      findFormInputGroup().vm.$emit('input', 'file-path');

      expect(wrapper.emitted('update-file-path')).toEqual([['file-path']]);
    });

    it('can select strategy for pipeline execution policy', () => {
      createComponent({ propsData: { strategy: INJECT, isPipelineExecution: true } });
      findStrategySelector().vm.$emit('select', OVERRIDE);
      expect(wrapper.emitted('select-strategy')).toEqual([[OVERRIDE]]);
    });
  });

  describe('group projects dropdown', () => {
    it('uses namespace for a group as path', () => {
      createComponent();

      expect(findGroupProjectsDropdown().props('groupFullPath')).toBe('gitlab-org');
    });

    it('uses rootNamespace for a project as path', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findGroupProjectsDropdown().props('groupFullPath')).toBe('gitlab');
    });
  });

  describe('validation', () => {
    it('is valid by default', () => {
      createComponent({ propsData: { selectedProject: { id: PROJECT_ID } } });
      expect(findRefSelector().props('state')).toBe(true);
      expect(findFormInputGroup().attributes('state')).toBe(undefined);
      expect(findFormGroup().attributes('state')).toBe(undefined);
    });

    describe('project and ref selectors', () => {
      it.each`
        title                                                         | filePath | doesFileExist | output
        ${'is valid when the file at the file path exists'}           | ${'ref'} | ${true}       | ${true}
        ${'is invalid when the file at the file path does not exist'} | ${'ref'} | ${false}      | ${false}
        ${'is valid when the file path is not provided'}              | ${null}  | ${true}       | ${true}
        ${'is valid when the file path is not provided'}              | ${null}  | ${false}      | ${true}
      `('$title', ({ filePath, doesFileExist, output }) => {
        createComponent({
          propsData: {
            filePath,
            doesFileExist,
            selectedProject: { id: PROJECT_ID },
          },
        });
        expect(findRefSelector().props('state')).toBe(output);
        expect(findGroupProjectsDropdown().props('state')).toBe(output);
      });
    });

    describe('file path selector', () => {
      it.each`
        title                                                         | filePath | doesFileExist | state        | message
        ${'is valid when the file exists at the file path'}           | ${'ref'} | ${true}       | ${'true'}    | ${''}
        ${'is invalid when the file does not exist at the file path'} | ${'ref'} | ${false}      | ${undefined} | ${"The file at that project, ref, and path doesn't exist"}
        ${'is invalid when the file path is not provided'}            | ${null}  | ${true}       | ${undefined} | ${"The file path can't be empty"}
        ${'is invalid when the file path is not provided'}            | ${null}  | ${false}      | ${undefined} | ${"The file path can't be empty"}
      `('$title', ({ filePath, doesFileExist, state, message }) => {
        createComponent({
          propsData: {
            filePath,
            doesFileExist,
          },
        });
        expect(findFormInputGroup().attributes('state')).toBe(state);
        expect(findFormGroup().attributes('state')).toBe(state);
        expect(findFormGroup().attributes('invalid-feedback')).toBe(message);
      });
    });
  });
});
