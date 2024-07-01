import { GlLink, GlSprintf, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { nextTick } from 'vue';
import MergeImmediatelyConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_immediately_confirmation_dialog.vue';
import MergeTrainRestartTrainConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_train_restart_train_confirmation_dialog.vue';
import MergeTrainFailedPipelineConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_train_failed_pipeline_confirmation_dialog.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ReadyToMerge from '~/vue_merge_request_widget/components/states/ready_to_merge.vue';
import {
  MWPS_MERGE_STRATEGY,
  MWCP_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
  MTWPS_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

describe('ReadyToMerge', () => {
  let wrapper;
  const showMock = jest.fn();

  const service = {
    merge: () => Promise.resolve({ res: { data: { status: '' } } }),
    poll: () => {},
  };

  const mr = {
    isPipelineActive: false,
    headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline' },
    isPipelineFailed: false,
    isPipelinePassing: false,
    isMergeAllowed: true,
    onlyAllowMergeIfPipelineSucceeds: false,
    ffOnlyEnabled: false,
    ffMergePossible: false,
    hasCI: false,
    ciStatus: null,
    sha: '12345678',
    squash: false,
    squashIsEnabledByDefault: false,
    squashIsReadonly: false,
    squashIsSelected: false,
    commitMessage: 'This is the commit message',
    squashCommitMessage: 'This is the squash commit message',
    commitMessageWithDescription: 'This is the commit message description',
    shouldRemoveSourceBranch: true,
    canRemoveSourceBranch: false,
    canMerge: true,
    targetBranch: 'main',
    availableAutoMergeStrategies: [MWPS_MERGE_STRATEGY],
    mergeImmediatelyDocsPath: 'path/to/merge/immediately/docs',
    mergeTrainsCount: 0,
    userPermissions: { canMerge: true },
    mergeable: true,
    transitionStateMachine: jest.fn(),
    state: 'readyToMerge',
    mergeTrainsSkipAllowed: false,
  };

  const createComponent = (
    mrUpdates = {},
    mountFn = shallowMountExtended,
    data = {},
    mergeTrainsSkipTrainFF = false,
  ) => {
    wrapper = mountFn(ReadyToMerge, {
      propsData: {
        mr: { ...mr, ...mrUpdates },
        service,
      },
      data() {
        return {
          loading: false,
          state: { ...mr, ...mrUpdates },
          ...data,
        };
      },
      stubs: {
        MergeImmediatelyConfirmationDialog: stubComponent(MergeImmediatelyConfirmationDialog, {
          methods: { show: showMock },
        }),
        GlSprintf,
        GlLink,
        MergeTrainFailedPipelineConfirmationDialog,
        MergeTrainRestartTrainConfirmationDialog: stubComponent(
          MergeTrainRestartTrainConfirmationDialog,
        ),
        GlDisclosureDropdown,
        GlDisclosureDropdownItem,
      },
      provide: {
        glFeatures: {
          mergeTrainsSkipTrain: mergeTrainsSkipTrainFF,
        },
      },
    });
  };

  const findMergeButton = () => wrapper.findByTestId('merge-button');
  const findMergeImmediatelyDropdown = () => wrapper.findByTestId('merge-immediately-dropdown');
  const findMergeImmediatelyButton = () => wrapper.findByTestId('merge-immediately-button');
  const findMergeTrainMergeNowRestartTrainButton = () =>
    wrapper.findByTestId('mt-merge-now-restart-button');
  const findMergeTrainMergeNowSkipTrainButton = () =>
    wrapper.findByTestId('mt-merge-now-skip-restart-button');
  const findMergeTrainFailedPipelineConfirmationDialog = () =>
    wrapper.findComponent(MergeTrainFailedPipelineConfirmationDialog);
  const findMergeImmediatelyConfirmationDialog = () =>
    wrapper.findComponent(MergeImmediatelyConfirmationDialog);
  const findMergeTrainRestartTrainConfirmationDialog = () =>
    wrapper.findComponent(MergeTrainRestartTrainConfirmationDialog);

  describe('Merge Immediately Dropdown', () => {
    it('should return false if auto merge is not available', () => {
      createComponent({
        headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline', active: true },
        onlyAllowMergeIfPipelineSucceeds: false,
        availableAutoMergeStrategies: [],
      });

      expect(findMergeImmediatelyDropdown().exists()).toBe(false);
    });

    it('should return false if the MR is not mergeable', () => {
      createComponent({
        headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline', active: true },
        mergeable: false,
      });

      expect(findMergeImmediatelyDropdown().exists()).toBe(false);
    });

    it('should return true if auto merge is available and "Pipelines must succeed" is disabled for the current project', () => {
      createComponent({
        onlyAllowMergeIfPipelineSucceeds: false,
      });

      expect(findMergeImmediatelyDropdown().exists()).toBe(true);
    });

    describe('with merge train auto merge strategy', () => {
      it.each`
        ffOnlyEnabled | ffMergePossible | isVisible
        ${false}      | ${false}        | ${true}
        ${false}      | ${true}         | ${true}
        ${true}       | ${false}        | ${false}
        ${true}       | ${true}         | ${true}
      `(
        'with ffOnlyEnabled $ffOnlyEnabled and ffMergePossible $ffMergePossible should be visible: $isVisible',
        ({ ffOnlyEnabled, ffMergePossible, isVisible }) => {
          createComponent({
            availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
            headPipeline: {
              id: 'gid://gitlab/Pipeline/1',
              path: 'path/to/pipeline',
              active: false,
            },
            ffOnlyEnabled,
            ffMergePossible,
            onlyAllowMergeIfPipelineSucceeds: false,
          });

          expect(findMergeImmediatelyDropdown().exists()).toBe(isVisible);
        },
      );
    });

    it('should display the new merge dropdown options for merge trains when the skip trains feature flag is enabled', () => {
      createComponent(
        {
          availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
          headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline', active: false },
          onlyAllowMergeIfPipelineSucceeds: false,
          mergeTrainsSkipAllowed: true,
        },
        shallowMountExtended,
        {},
        true,
      );

      expect(findMergeTrainMergeNowRestartTrainButton().exists()).toBe(true);
      expect(findMergeTrainMergeNowSkipTrainButton().exists()).toBe(true);
    });
  });

  describe('merge train failed confirmation dialog', () => {
    it.each`
      mergeStrategy           | isPipelineFailed | isVisible
      ${MT_MERGE_STRATEGY}    | ${true}          | ${true}
      ${MT_MERGE_STRATEGY}    | ${false}         | ${false}
      ${MTWPS_MERGE_STRATEGY} | ${true}          | ${false}
      ${MWPS_MERGE_STRATEGY}  | ${true}          | ${false}
      ${MWCP_MERGE_STRATEGY}  | ${true}          | ${false}
    `(
      'with merge stragtegy $mergeStrategy and pipeline failed status of $isPipelineFailed we should show the modal: $isVisible',
      async ({ mergeStrategy, isPipelineFailed, isVisible }) => {
        createComponent(
          {
            availableAutoMergeStrategies: [mergeStrategy],
            headPipeline: {
              id: 'gid://gitlab/Pipeline/1',
              path: 'path/to/pipeline',
              status: isPipelineFailed ? 'FAILED' : 'PASSED',
            },
          },
          mountExtended,
        );
        const modalConfirmation = findMergeTrainFailedPipelineConfirmationDialog();

        await findMergeButton().vm.$emit('click');

        expect(modalConfirmation.props('visible')).toBe(isVisible);
      },
    );
  });

  describe('merge immediately warning dialog', () => {
    const clickMergeImmediately = async (
      dialog = findMergeImmediatelyConfirmationDialog(),
      button = findMergeImmediatelyButton(),
    ) => {
      expect(dialog.exists()).toBe(true);

      button.vm.$emit('action');

      await nextTick();
    };

    it('should show a warning dialog asking for confirmation if the user is trying to skip the merge train', async () => {
      createComponent({ availableAutoMergeStrategies: [MT_MERGE_STRATEGY] });

      await clickMergeImmediately();

      expect(showMock).toHaveBeenCalled();

      expect(findMergeTrainFailedPipelineConfirmationDialog().props('visible')).toBe(false);
      expect(findMergeButton().text()).toBe('Merge');
      expect(mr.transitionStateMachine).toHaveBeenCalledTimes(0);
    });

    it('should perform the merge when the user confirms their intent to merge immediately', async () => {
      createComponent({ availableAutoMergeStrategies: [MT_MERGE_STRATEGY] });

      await clickMergeImmediately();

      findMergeImmediatelyConfirmationDialog().vm.$emit('mergeImmediately');

      await nextTick();

      expect(findMergeTrainFailedPipelineConfirmationDialog().props('visible')).toBe(false);
      expect(mr.transitionStateMachine).toHaveBeenCalledWith({ transition: 'start-merge' });
    });

    it('should not ask for confirmation in non-merge train scenarios', async () => {
      createComponent({
        headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline', active: true },
        onlyAllowMergeIfPipelineSucceeds: false,
      });

      await clickMergeImmediately();

      expect(showMock).not.toHaveBeenCalled();
      expect(findMergeTrainFailedPipelineConfirmationDialog().props('visible')).toBe(false);
      expect(mr.transitionStateMachine).toHaveBeenCalled();
    });

    it('starts to merge a merge request when restarting a merge train with the new confirmation dialog', async () => {
      createComponent(
        {
          availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
          headPipeline: {
            id: 'gid://gitlab/Pipeline/1',
            path: 'path/to/pipeline',
            status: 'PASSED',
          },
          mergeTrainsSkipAllowed: true,
        },
        shallowMountExtended,
        {},
        true,
      );

      findMergeTrainRestartTrainConfirmationDialog().vm.$emit('show');

      await clickMergeImmediately(
        findMergeTrainRestartTrainConfirmationDialog(),
        findMergeTrainMergeNowRestartTrainButton(),
      );

      findMergeTrainRestartTrainConfirmationDialog().vm.$emit('processMergeTrainMerge');

      await nextTick();

      expect(mr.transitionStateMachine).toHaveBeenCalledWith({ transition: 'start-merge' });
    });

    it('does not contain the new confirmation dialog for merging merge trains immediately when the mergeTrainSkipTrain feature flag is disabled', () => {
      createComponent({
        availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
        mergeTrainsSkipAllowed: true,
      });

      expect(findMergeTrainRestartTrainConfirmationDialog().exists()).toBe(false);
    });

    it('contains the new confirmation dialog for merging merge trains immediately when the mergeTrainSkipTrain feature flag is enabled', () => {
      createComponent(
        { availableAutoMergeStrategies: [MT_MERGE_STRATEGY], mergeTrainsSkipAllowed: true },
        shallowMountExtended,
        {},
        true,
      );

      expect(findMergeTrainRestartTrainConfirmationDialog().exists()).toBe(true);
    });

    it('should not ask for confirmation in non-merge train scenarios with the new confirmation dialog', async () => {
      createComponent(
        {
          headPipeline: { id: 'gid://gitlab/Pipeline/1', path: 'path/to/pipeline', active: true },
          onlyAllowMergeIfPipelineSucceeds: false,
          mergeTrainsSkipAllowed: true,
        },
        shallowMountExtended,
        {},
        true,
      );

      await clickMergeImmediately();

      expect(showMock).not.toHaveBeenCalled();
      expect(findMergeTrainRestartTrainConfirmationDialog().props('visible')).toBe(false);
      expect(mr.transitionStateMachine).toHaveBeenCalled();
    });
  });

  describe('Merge button text', () => {
    it.each`
      availableAutoMergeStrategies | mergeTrainsCount | expectedText
      ${[]}                        | ${0}             | ${'Merge'}
      ${[MWPS_MERGE_STRATEGY]}     | ${0}             | ${'Set to auto-merge'}
      ${[MWCP_MERGE_STRATEGY]}     | ${0}             | ${'Set to auto-merge'}
      ${[MT_MERGE_STRATEGY]}       | ${0}             | ${'Merge'}
      ${[MT_MERGE_STRATEGY]}       | ${1}             | ${'Merge'}
      ${[MTWPS_MERGE_STRATEGY]}    | ${0}             | ${'Set to auto-merge'}
      ${[MTWPS_MERGE_STRATEGY]}    | ${1}             | ${'Set to auto-merge'}
    `(
      'displays $expectedText with merge strategy $availableAutoMergeStrategies and merge train count $mergeTrainsCount',
      ({ availableAutoMergeStrategies, mergeTrainsCount, expectedText }) => {
        createComponent({ availableAutoMergeStrategies, mergeTrainsCount });

        expect(findMergeButton().text()).toBe(expectedText);
      },
    );

    it('displays "Merge in progress"', () => {
      createComponent({}, shallowMountExtended, { isMergingImmediately: true });

      expect(findMergeButton().text()).toBe('Merge in progress');
    });
  });

  describe('merge button disabled state', () => {
    it('should be disabled if preventMerge is set', () => {
      createComponent({ preventMerge: true });

      expect(findMergeButton().props('disabled')).toBe(true);
    });

    it('should not be disabled if preventMerge is false', () => {
      createComponent({ preventMerge: false });

      expect(findMergeButton().props('disabled')).toBe(false);
    });
  });
});
