import { GlForm, GlFormInput, GlPopover, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemProgress from 'ee/work_items/components/work_item_progress.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { updateWorkItemMutationResponse } from 'jest/work_items/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('WorkItemProgress component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';

  const updateWorkItemMutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);

  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findDisplayedValue = () => wrapper.findByTestId('progress-displayed-value');
  const findApplyButton = () => wrapper.findByTestId('apply-progress');
  const findEditButton = () => wrapper.findByTestId('edit-progress');
  const findProgressPopover = () => wrapper.findComponent(GlPopover);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createComponent = ({
    canUpdate = false,
    okrsMvc = true,
    okrAutomaticRollups = false,
    workItemType = 'Objective',
    progress = 0,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemProgress, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, updateWorkItemMutationHandler]]),
      propsData: {
        canUpdate,
        progress,
        workItemId,
        workItemType,
      },
      provide: {
        glFeatures: {
          okrsMvc,
          okrAutomaticRollups,
        },
      },
    });
  };

  afterEach(() => {
    updateWorkItemMutationHandler.mockClear();
  });

  it('displays progress popover if the feature is enabled', () => {
    createComponent({ okrAutomaticRollups: true });
    expect(findProgressPopover().exists()).toBe(true);
  });

  it('does not display progress popover if the feature is disabled', () => {
    createComponent({ okrAutomaticRollups: false });
    expect(findProgressPopover().exists()).toBe(false);
  });

  describe('when user cannot update progress', () => {
    beforeEach(() => {
      createComponent({ canUpdate: false });
    });

    it('does not render the form', () => {
      expect(findForm().exists()).toBe(false);
    });

    it('does not render `Edit` button', () => {
      expect(findEditButton().exists()).toBe(false);
    });

    it('renders the progress value', () => {
      expect(findDisplayedValue().text()).toBe('0%');
    });
  });

  describe('when user can update progress', () => {
    describe('when not editing', () => {
      beforeEach(() => {
        createComponent({ canUpdate: true, progress: 10 });
      });

      it('renders the progress value', () => {
        expect(findDisplayedValue().text()).toBe('10%');
      });

      it('updates displayed progress value when the progress prop changes', async () => {
        expect(findDisplayedValue().text()).toBe('10%');

        await wrapper.setProps({ progress: 20 });
        expect(findDisplayedValue().text()).toBe('20%');
      });

      it('does not render the form', () => {
        expect(findForm().exists()).toBe(false);
      });

      it('renders an `Edit` button', () => {
        expect(findEditButton().exists()).toBe(true);
      });

      it('opens the form when clicking the `Edit` button', async () => {
        expect(findForm().exists()).toBe(false);

        findEditButton().vm.$emit('click');
        await nextTick();

        expect(findForm().exists()).toBe(true);
      });
    });

    describe('when editing', () => {
      beforeEach(async () => {
        createComponent({ canUpdate: true, progress: 10 });
        findEditButton().vm.$emit('click');
        await nextTick();
      });

      it('renders the form', () => {
        expect(findForm().exists()).toBe(true);
      });

      it('does not render the progress value', () => {
        expect(findDisplayedValue().exists()).toBe(false);
      });

      it('does not render the `Edit` button', () => {
        expect(findEditButton().exists()).toBe(false);
      });

      it('does not call the mutation and closes the form when the progress value is not changed', async () => {
        findInput().vm.$emit('input', '10');
        findForm().vm.$emit('submit', new Event('submit'));
        await nextTick();

        expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
        expect(findForm().exists()).toBe(false);
      });

      it.each(['-1', '101', 'abc', '--70'])(
        'does not call the mutation and closes the form when the progress value is not valid, e.g %s',
        async (value) => {
          findInput().vm.$emit('input', value);
          findForm().vm.$emit('submit', new Event('submit'));
          await nextTick();

          expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
          expect(findForm().exists()).toBe(false);
        },
      );

      describe('when the progress value is valid', () => {
        it('calls the mutation with the correct variables on `Apply` button click', () => {
          findInput().vm.$emit('input', '20');
          findApplyButton().vm.$emit('click');

          expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: 'gid://gitlab/WorkItem/1',
              progressWidget: { currentValue: 20 },
            },
          });
        });

        it('calls the mutation on blurring the input field', async () => {
          findInput().vm.$emit('input', '20');
          findInput().vm.$emit('blur');

          await waitForPromises();

          expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: 'gid://gitlab/WorkItem/1',
              progressWidget: { currentValue: 20 },
            },
          });
        });

        it('shows the loading spinner while the mutation is in progress', async () => {
          findInput().vm.$emit('input', '20');
          findApplyButton().vm.$emit('click');
          await nextTick();

          expect(findLoadingIcon().exists()).toBe(true);
        });

        it('disables the `Apply` button while the mutation is in progress', async () => {
          findInput().vm.$emit('input', '20');
          findApplyButton().vm.$emit('click');
          await nextTick();

          expect(findApplyButton().props('disabled')).toBe(true);
        });

        it('tracks the event', () => {
          const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

          findInput().vm.$emit('input', '20');
          findApplyButton().vm.$emit('click');

          expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_progress', {
            category: TRACKING_CATEGORY_SHOW,
            label: 'item_progress',
            property: 'type_Objective',
          });
        });

        it('closes the form when the mutation is successful', async () => {
          findInput().vm.$emit('input', '20');
          findApplyButton().vm.$emit('click');
          await waitForPromises();

          expect(findForm().exists()).toBe(false);
        });

        describe('when mutation throws an error', () => {
          const error = new Error('GraphQL error');

          beforeEach(() => {
            updateWorkItemMutationHandler.mockRejectedValue(error);
          });

          it('emits an error and tracks it with Sentry', async () => {
            findInput().vm.$emit('input', '20');
            findApplyButton().vm.$emit('click');

            await waitForPromises();

            expect(Sentry.captureException).toHaveBeenCalledWith(error);
          });

          it('resets the progress value to the original value', async () => {
            findInput().vm.$emit('input', '20');
            findApplyButton().vm.$emit('click');

            await waitForPromises();

            expect(findDisplayedValue().text()).toBe('10%');
          });

          it('closes the form', async () => {
            findInput().vm.$emit('input', '20');
            findApplyButton().vm.$emit('click');

            await waitForPromises();

            expect(findForm().exists()).toBe(false);
          });
        });
      });
    });
  });
});
