import { GlFormInput, GlSprintf, GlFormGroup, GlFormInputGroup, GlTruncate } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CodeBlockSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_source_selector.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_file_path.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';
import RefSelector from '~/ref/components/ref_selector.vue';
import { INSERTED_CODE_BLOCK } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('CodeBlockFilePath', () => {
  let wrapper;

  const PROJECT_ID = 'gid://gitlab/Project/29';

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(CodeBlockFilePath, {
      propsData: {
        selectedType: INSERTED_CODE_BLOCK,
        ...propsData,
      },
      stubs: {
        GlSprintf,
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
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findRefSelector = () => wrapper.findComponent(RefSelector);
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

    it('renders action type selector', () => {
      expect(findCodeBlockSourceSelector().exists()).toBe(true);
      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);
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

    it('renders selected project and ref selector', () => {
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
      expect(findRefSelector().exists()).toBe(true);
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
