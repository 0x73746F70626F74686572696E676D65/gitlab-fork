import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import Api from 'ee/api';
import {
  buildCustomCodeAction,
  toYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import CodeBlockSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_source_selector.vue';
import CodeBlockAction from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_action.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_file_path.vue';
import CodeBlockImport from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_import.vue';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';
import {
  INSERTED_CODE_BLOCK,
  LINKED_EXISTING_FILE,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';

const actionId = 'action_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(actionId));

jest.mock('ee/api');

describe('CodeBlockAction', () => {
  let wrapper;
  let requestHandler;

  const project = {
    id: 'gid://gitlab/Project/29',
    fullPath: 'project-path',
    repository: {
      rootRef: 'spooky-stuff',
    },
  };

  const projectId = 29;
  const defaultProjectId = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: projectId,
      },
    },
  });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getProjectId, handler]]);
  };

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(CodeBlockAction, {
      apolloProvider: createMockApolloProvider(defaultProjectId),
      propsData: {
        initAction: buildCustomCodeAction(),
        ...propsData,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.GROUP,
        namespacePath: 'gitlab-org',
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findCodeBlockFilePath = () => wrapper.findComponent(CodeBlockFilePath);
  const findCodeBlockSourceSelector = () => wrapper.findComponent(CodeBlockSourceSelector);
  const findYamlEditor = () => wrapper.findComponent(YamlEditor);
  const findCodeBlockActionTooltip = () => wrapper.findComponent(PolicyPopover);
  const findCodeBlockImport = () => wrapper.findComponent(CodeBlockImport);

  describe('default state', () => {
    it('should render yaml editor in default state', async () => {
      createComponent();

      await waitForPromises();
      expect(findYamlEditor().exists()).toBe(true);
      expect(findCodeBlockActionTooltip().exists()).toBe(true);
      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);
      expect(findCodeBlockImport().props('hasExistingCode')).toBe(false);
    });

    it('should change code source type', async () => {
      createComponent();

      await waitForPromises();

      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);

      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      expect(findCodeBlockSourceSelector().exists()).toBe(false);
      expect(findCodeBlockFilePath().props('selectedType')).toBe(LINKED_EXISTING_FILE);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            scan: 'custom',
            id: 'action_0',
          },
        ],
      ]);

      await findCodeBlockFilePath().vm.$emit('select-type', INSERTED_CODE_BLOCK);
      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);
      expect(findCodeBlockFilePath().exists()).toBe(false);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            scan: 'custom',
            id: 'action_0',
          },
        ],
        [
          {
            scan: 'custom',
            id: 'action_0',
          },
        ],
      ]);
    });
  });

  describe('code block', () => {
    const fileContents = 'foo: bar';

    it('should render the import button when code exists', async () => {
      createComponent();
      await waitForPromises();
      await findYamlEditor().vm.$emit('input', fileContents);
      expect(findCodeBlockImport().props('hasExistingCode')).toBe(true);
      expect(wrapper.emitted('changed')).toEqual([
        [{ ...buildCustomCodeAction(), ci_configuration: fileContents }],
      ]);
    });

    it('updates the yaml when a file is imported', async () => {
      createComponent();
      await waitForPromises();
      await findCodeBlockImport().vm.$emit('changed', fileContents);
      expect(findYamlEditor().props('value')).toBe(fileContents);
      expect(findCodeBlockImport().props('hasExistingCode')).toBe(true);
      expect(wrapper.emitted('changed')).toEqual([
        [{ ...buildCustomCodeAction(), ci_configuration: fileContents }],
      ]);
    });

    it('renders existing custom ci configuration', async () => {
      createComponent({
        propsData: {
          initAction: {
            ci_configuration: fileContents,
          },
        },
      });

      await waitForPromises();

      expect(findYamlEditor().props('value')).toBe(fileContents);
      expect(findCodeBlockImport().props('hasExistingCode')).toBe(true);
    });

    it('renders existing custom ci configuration for empty content', async () => {
      createComponent({
        propsData: {
          initAction: {
            ci_configuration: undefined,
          },
        },
      });

      await waitForPromises();

      expect(findYamlEditor().props('value')).toBe('');
      expect(findCodeBlockImport().props('hasExistingCode')).toBe(false);
    });
  });

  describe('linked file mode', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render file path form', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      expect(findYamlEditor().exists()).toBe(false);
      expect(findCodeBlockFilePath().exists()).toBe(true);
    });

    it('should set file path', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      findCodeBlockFilePath().vm.$emit('update-file-path', 'file/path');

      expect(wrapper.emitted('changed')).toEqual([
        [buildCustomCodeAction()],
        [
          {
            ...buildCustomCodeAction(),
            ci_configuration: toYaml({ include: { file: 'file/path' } }),
          },
        ],
      ]);
    });

    it('should reset action when action type is changed', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);
      await findCodeBlockFilePath().vm.$emit('select-type', INSERTED_CODE_BLOCK);

      expect(wrapper.emitted('changed')).toEqual([
        [buildCustomCodeAction()],
        [buildCustomCodeAction()],
      ]);
    });
  });

  describe('existing linked file', () => {
    it('should render linked file mode when file exist', () => {
      createComponent({
        propsData: {
          initAction: {
            ci_configuration: toYaml({
              include: {
                file: 'file',
              },
            }),
          },
        },
      });

      expect(findCodeBlockFilePath().props('selectedType')).toBe(LINKED_EXISTING_FILE);
      expect(findCodeBlockFilePath().props('filePath')).toBe('file');
    });

    it('should render linked file mode when project exist', async () => {
      createComponent({
        propsData: {
          initAction: {
            ci_configuration: toYaml({
              include: {
                project: 'file',
              },
            }),
          },
        },
      });
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'file' });
      expect(findCodeBlockFilePath().props('selectedType')).toBe(LINKED_EXISTING_FILE);
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual({
        fullPath: 'file',
        id: 29,
      });
    });

    it('should render linked file mode when project id exist and ref is selected', () => {
      createComponent({
        propsData: {
          initAction: {
            ci_configuration: toYaml({
              include: {
                ref: 'ref',
              },
            }),
          },
        },
      });

      expect(findCodeBlockFilePath().props('selectedType')).toBe(LINKED_EXISTING_FILE);
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual(null);
      expect(findCodeBlockFilePath().props('selectedRef')).toBe('ref');
    });
  });

  describe('changing linked file parameters', () => {
    beforeEach(() => {
      createComponent();
    });

    it('selects ref', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      findCodeBlockFilePath().vm.$emit('select-ref', 'ref');

      expect(wrapper.emitted('changed')[1]).toEqual([
        { ...buildCustomCodeAction(), ci_configuration: toYaml({ include: { ref: 'ref' } }) },
      ]);
    });

    it('selects type', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      await findCodeBlockFilePath().vm.$emit('select-type', INSERTED_CODE_BLOCK);

      expect(wrapper.emitted('changed')[1]).toEqual([buildCustomCodeAction()]);
      expect(findCodeBlockSourceSelector().props('selectedType')).toBe(INSERTED_CODE_BLOCK);
    });

    it('updates file path', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      findCodeBlockFilePath().vm.$emit('update-file-path', 'file-path');

      expect(wrapper.emitted('changed')[1]).toEqual([
        {
          ...buildCustomCodeAction(),
          ci_configuration: toYaml({ include: { file: 'file-path' } }),
        },
      ]);
    });

    it('updates project', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);
      await findCodeBlockFilePath().vm.$emit('select-project', project);

      expect(wrapper.emitted('changed')[1]).toEqual([
        {
          ...buildCustomCodeAction(),
          ci_configuration: toYaml({ include: { project: project.fullPath } }),
        },
      ]);
    });

    it('clears project on deselect', async () => {
      await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);

      await findCodeBlockFilePath().vm.$emit('select-project', undefined);

      expect(wrapper.emitted('changed')[1]).toEqual([
        { ...buildCustomCodeAction(), ci_configuration: toYaml({ include: {} }) },
      ]);
    });

    describe('file validation', () => {
      beforeEach(() => {
        jest.spyOn(Api, 'getFile').mockResolvedValue();
      });

      afterEach(() => {
        jest.clearAllMocks();
      });

      describe('no validation', () => {
        it('does not validate on new linked file section', async () => {
          createComponent();
          await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);
          expect(Api.getFile).not.toHaveBeenCalled();
        });

        it('does not validate when ref is not selected', async () => {
          createComponent({
            propsData: {
              initAction: {
                ci_configuration: toYaml({
                  include: {
                    project: 'fullPath',
                  },
                }),
              },
            },
          });
          await waitForPromises();
          expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'fullPath' });
          expect(Api.getFile).not.toHaveBeenCalled();
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });
      });

      describe('existing selection', () => {
        it('succeeds validation', async () => {
          createComponent({
            propsData: {
              initAction: {
                ci_configuration: toYaml({
                  include: {
                    project: 'fullPath',
                    ref: 'main',
                  },
                }),
              },
            },
          });
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'fullPath' });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });

        it('fails validation', async () => {
          jest.spyOn(Api, 'getFile').mockRejectedValue();
          createComponent({
            propsData: {
              initAction: {
                ci_configuration: toYaml({
                  include: {
                    project: 'fullPath',
                    ref: 'not-main',
                  },
                }),
              },
            },
          });
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'fullPath' });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
        });
      });

      describe('successful validation', () => {
        describe('simple scenarios', () => {
          beforeEach(() => {
            createComponent({
              propsData: {
                initAction: {
                  ci_configuration: toYaml({
                    include: { project: 'fullPath', ref: 'main', file: 'path' },
                  }),
                },
              },
            });
          });

          it('verifies on file path change', async () => {
            await wrapper.setProps({
              initAction: {
                ci_configuration: toYaml({ include: { ref: 'main', file: 'new-path' } }),
              },
            });
            await waitForPromises();
            expect(Api.getFile).toHaveBeenCalledTimes(2);
            expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
          });

          it('verifies on project change when ref is selected', async () => {
            await findCodeBlockFilePath().vm.$emit('select-project', project);
            await waitForPromises();
            expect(Api.getFile).toHaveBeenCalledTimes(3);
            expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
          });

          it('verifies on ref change', async () => {
            await wrapper.setProps({
              initAction: {
                ci_configuration: toYaml({ include: { ref: 'new-ref', file: 'path' } }),
              },
            });
            await waitForPromises();
            expect(Api.getFile).toHaveBeenCalledTimes(2);
            expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
          });
        });

        describe('complex scenarios', () => {
          it('verifies on project change when ref is not selected', async () => {
            await createComponent({
              propsData: {
                initAction: {
                  ci_configuration: toYaml({ include: { project: 'fullPath', file: 'path' } }),
                },
              },
            });
            await waitForPromises();

            expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'fullPath' });
            await findCodeBlockFilePath().vm.$emit('select-project', project);
            await waitForPromises();
            expect(Api.getFile).toHaveBeenCalledTimes(1);
            expect(Api.getFile).toHaveBeenCalledWith(29, 'path', { ref: 'spooky-stuff' });
            expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
          });
        });
      });

      describe('failed validation', () => {
        it('fails when a file does not exists on a ref', async () => {
          jest.spyOn(Api, 'getFile').mockRejectedValue();
          createComponent({
            propsData: {
              initAction: {
                ci_configuration: toYaml({
                  include: {
                    project: 'fullPath',
                    ref: 'not-main',
                  },
                }),
              },
            },
          });
          await wrapper.setProps({
            initAction: { ci_configuration: toYaml({ include: { ref: 'new-ref' } }) },
          });
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
        });

        it('fails validation when a project is not selected', async () => {
          createComponent();
          await findCodeBlockSourceSelector().vm.$emit('select', LINKED_EXISTING_FILE);
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
        });
      });

      describe('resetting validation', () => {
        it('resets validation on change', async () => {
          jest.spyOn(Api, 'getFile').mockRejectedValue();
          createComponent({
            propsData: {
              initAction: {
                ci_configuration: toYaml({
                  include: {
                    project: 'fullPath',
                    ref: 'main',
                  },
                }),
              },
            },
          });
          await waitForPromises();
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
          await wrapper.setProps({
            initAction: { ci_configuration_path: { ref: 'new-ref', file: 'new-path' } },
          });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });
      });
    });
  });
});
