import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import Api from 'ee/api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_file_path.vue';
import {
  INJECT,
  OVERRIDE,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { mockWithoutRefPipelineExecutionObject } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';

jest.mock('ee/api');

describe('ActionSection', () => {
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
  const ref = 'main';
  const filePath = 'path/to/ci/file.yml';
  const fullPath = 'GitLab.org/GitLab';

  const defaultProjectId = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: projectId,
      },
    },
  });
  const defaultAction = mockWithoutRefPipelineExecutionObject.content;

  const defaultProps = {
    action: defaultAction,
    strategy: mockWithoutRefPipelineExecutionObject.pipeline_config_strategy,
  };

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getProjectId, handler]]);
  };

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ActionSection, {
      apolloProvider: createMockApolloProvider(defaultProjectId),
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      provide: {
        ...provide,
      },
    });
  };

  const findCodeBlockFilePath = () => wrapper.findComponent(CodeBlockFilePath);

  describe('rendering', () => {
    it('renders code block file path component correctly', async () => {
      factory();
      await waitForPromises();
      await nextTick();

      expect(findCodeBlockFilePath().exists()).toBe(true);
      expect(requestHandler).toHaveBeenCalledWith({ fullPath });
      expect(findCodeBlockFilePath().props()).toEqual(
        expect.objectContaining({
          filePath: '.pipeline-execution.yml',
          strategy: INJECT,
          selectedRef: '',
          selectedProject: { fullPath, id: 29 },
          doesFileExist: true,
        }),
      );
    });

    it('should render linked file mode when project fullPath exist', async () => {
      factory({ propsData: { action: { include: { project: fullPath } } } });
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledWith({ fullPath });
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual({
        id: 29,
        fullPath,
      });
    });

    it('should render linked file mode when ref is selected', () => {
      factory({ propsData: { action: { include: { ref: 'ref' } } } });

      expect(requestHandler).not.toHaveBeenCalled();
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual(null);
      expect(findCodeBlockFilePath().props('selectedRef')).toBe('ref');
    });
  });

  describe('changing linked file parameters', () => {
    beforeEach(() => {
      factory();
    });

    it('selects ref', () => {
      findCodeBlockFilePath().vm.$emit('select-ref', ref);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: { ...defaultAction.include, ref } }],
      ]);
    });

    it('updates file path', () => {
      findCodeBlockFilePath().vm.$emit('update-file-path', filePath);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: { ...defaultAction.include, file: filePath } }],
      ]);
    });

    it('updates project', async () => {
      await findCodeBlockFilePath().vm.$emit('select-project', project);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: { ...defaultAction.include, project: project.fullPath } }],
      ]);
    });

    it.each([OVERRIDE, INJECT])('updates strategy when the value is %o', async ({ strategy }) => {
      await findCodeBlockFilePath().vm.$emit('select-strategy', strategy);
      expect(wrapper.emitted('changed')).toEqual([['pipeline_config_strategy', strategy]]);
    });

    it('clears project on deselect', async () => {
      await findCodeBlockFilePath().vm.$emit('select-project', undefined);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: { file: defaultAction.include.file } }],
      ]);
    });
  });

  describe('file validation', () => {
    beforeEach(() => {
      jest.spyOn(Api, 'getFile').mockResolvedValue();
    });

    afterEach(() => {
      jest.clearAllMocks();
    });

    describe('no validation', () => {
      it('does not validate on new linked file section', () => {
        factory();
        expect(Api.getFile).not.toHaveBeenCalled();
      });

      it('does not validate when ref is not selected', async () => {
        factory({ propsData: { action: { include: { project: fullPath } } } });
        await waitForPromises();
        expect(Api.getFile).not.toHaveBeenCalled();
        expect(requestHandler).toHaveBeenCalledWith({ fullPath });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
      });
    });

    describe('existing selection', () => {
      it('makes a call to validate the selection', async () => {
        factory({ propsData: { action: { include: { project: fullPath, ref } } } });
        await waitForPromises();
        expect(Api.getFile).toHaveBeenCalledWith(projectId, undefined, { ref });
      });

      it('succeeds validation', async () => {
        factory({ propsData: { action: { include: { project: fullPath, ref } } } });
        await waitForPromises();
        expect(Api.getFile).toHaveBeenCalledTimes(1);
        expect(requestHandler).toHaveBeenCalledWith({ fullPath });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
      });

      it('fails validation', async () => {
        jest.spyOn(Api, 'getFile').mockRejectedValue();
        factory({ propsData: { action: { include: { project: fullPath, ref: 'not-main' } } } });
        await waitForPromises();
        expect(requestHandler).toHaveBeenCalledWith({ fullPath });
        expect(Api.getFile).toHaveBeenCalledTimes(1);
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
      });
    });

    describe('successful validation', () => {
      describe('simple scenarios', () => {
        beforeEach(async () => {
          factory({
            propsData: { action: { include: { project: fullPath, ref, file: filePath } } },
          });
          await waitForPromises();
        });

        it('verifies on file path change', async () => {
          expect(Api.getFile).toHaveBeenCalledTimes(1);
          await wrapper.setProps({ action: { include: { ref, file: 'new-path' } } });
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(Api.getFile).toHaveBeenLastCalledWith(projectId, 'new-path', { ref });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });

        it('verifies on project change when ref is selected', async () => {
          expect(Api.getFile).toHaveBeenCalledTimes(1);
          await findCodeBlockFilePath().vm.$emit('select-project', project);
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(Api.getFile).toHaveBeenLastCalledWith(projectId, filePath, { ref });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });

        it('verifies on ref change', async () => {
          expect(Api.getFile).toHaveBeenCalledTimes(1);
          await wrapper.setProps({ action: { include: { ref: 'new-ref', file: filePath } } });
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledTimes(2);
          expect(Api.getFile).toHaveBeenLastCalledWith(projectId, filePath, { ref: 'new-ref' });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });
      });

      describe('complex scenarios', () => {
        it('verifies on project change when ref is not selected', async () => {
          await factory({ propsData: { action: { include: { id: projectId, file: filePath } } } });
          await findCodeBlockFilePath().vm.$emit('select-project', project);
          await waitForPromises();
          expect(Api.getFile).toHaveBeenCalledWith(projectId, filePath, {
            ref: project.repository.rootRef,
          });
          expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
        });
      });
    });

    describe('failed validation', () => {
      it('fails when a file does not exists on a ref', async () => {
        jest.spyOn(Api, 'getFile').mockRejectedValue();
        factory({ propsData: { action: { include: { project: fullPath, ref: 'not-main' } } } });
        await wrapper.setProps({ action: { include: { ref: 'new-ref' } } });
        await waitForPromises();
        expect(Api.getFile).toHaveBeenCalledTimes(1);
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
      });

      it('fails validation when a project is not selected', async () => {
        await factory({ propsData: { action: { include: {} } } });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
      });
    });

    describe('updating validation status', () => {
      it('updates a failed validation to a successful one', async () => {
        jest.spyOn(Api, 'getFile').mockRejectedValue();
        factory({ propsData: { action: { include: { project: fullPath, ref } } } });
        await waitForPromises();
        expect(requestHandler).toHaveBeenCalledWith({ fullPath });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
        await wrapper.setProps({ action: { include: { ref: 'new-ref', file: 'new-path' } } });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
      });
    });
  });
});
