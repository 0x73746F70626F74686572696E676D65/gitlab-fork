import { GlForm, GlFormInput, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { __ } from '~/locale';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { updateWorkItemMutationResponse } from 'jest/work_items/mock_data';

describe('WorkItemWeight component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const workItemType = 'Task';

  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.find('[data-testid="edit-weight"]');
  const findApplyButton = () => wrapper.find('[data-testid="apply-weight"]');
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findClearButton = () => wrapper.find('[data-testid="remove-weight"]');

  const createComponent = ({
    canUpdate = true,
    hasIssueWeightsFeature = true,
    isEditing = false,
    weight,
    workItemIid = '1',
    mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse),
  } = {}) => {
    wrapper = mountExtended(WorkItemWeight, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        weight,
        workItemId,
        workItemIid,
        workItemType,
      },
      provide: {
        hasIssueWeightsFeature,
      },
    });

    if (isEditing) {
      findEditButton().trigger('click');
    }
  };

  it('renders nothing if license not available', async () => {
    createComponent({ hasIssueWeightsFeature: false });

    await nextTick();

    expect(findHeader().exists()).toBe(false);
    expect(findForm().exists()).toBe(false);
  });

  describe('label', () => {
    it('shows header when not editing', () => {
      createComponent();

      expect(findHeader().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(false);
      expect(findLabel().exists()).toBe(false);
    });

    it('shows label and hides header while editing', async () => {
      createComponent({ isEditing: true });

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(true);
    });

    it('shows loading spinner while updating', async () => {
      createComponent({
        isEditing: true,
        weight: 0,
        canUpdate: true,
      });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('edit button', () => {
    it('is not shown if user cannot edit', () => {
      createComponent({ canUpdate: false });

      expect(findEditButton().exists()).toBe(false);
    });

    it('is shown if user can edit', () => {
      createComponent({ canUpdate: true });

      expect(findEditButton().exists()).toBe(true);
    });

    it('triggers edit mode on click', async () => {
      createComponent();

      findEditButton().trigger('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findForm().exists()).toBe(true);
    });

    it('is replaced by Apply button while editing', async () => {
      createComponent();

      findEditButton().trigger('click');

      await nextTick();

      expect(findEditButton().exists()).toBe(false);
      expect(findApplyButton().exists()).toBe(true);
    });
  });

  describe('value', () => {
    it('shows None when no weight is set', () => {
      createComponent();

      expect(wrapper.text()).toContain(__('None'));
    });

    it('shows weight when weight is set', () => {
      createComponent({ weight: 4 });

      expect(wrapper.text()).not.toContain(__('None'));
      expect(wrapper.text()).toContain('4');
    });
  });

  describe('form', () => {
    it('is not shown while not editing', async () => {
      await createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('is shown while editing', async () => {
      await createComponent({ isEditing: true });

      expect(findForm().exists()).toBe(true);
    });
  });

  describe('weight input', () => {
    it('is not shown while not editing', async () => {
      await createComponent();

      expect(findInput().exists()).toBe(false);
    });

    it('has weight-y attributes', async () => {
      await createComponent({ isEditing: true });

      expect(findInput().attributes()).toEqual(
        expect.objectContaining({
          min: '0',
          type: 'number',
        }),
      );
    });

    it('clear button triggers mutation', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        isEditing: true,
        weight: 0,
        mutationHandler: mutationSpy,
        canUpdate: true,
      });

      await nextTick();

      findClearButton().trigger('click');

      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          weightWidget: {
            weight: null,
          },
        },
      });
    });

    it('calls a mutation to update the weight when the input value is different', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        isEditing: true,
        weight: 0,
        mutationHandler: mutationSpy,
        canUpdate: true,
      });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          weightWidget: {
            weight: 1,
          },
        },
      });
    });

    it('is disabled while updating, and removed after', async () => {
      createComponent({
        isEditing: true,
        weight: 0,
        canUpdate: true,
      });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      await nextTick();

      expect(findInput().attributes('disabled')).toBe('disabled');

      await waitForPromises();

      expect(findInput().exists()).toBe(false);
    });

    it('does not call a mutation to update the weight when the input value is the same', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({ isEditing: true, mutationHandler: mutationSpy, canUpdate: true });

      await nextTick();

      findInput().trigger('blur');

      expect(mutationSpy).not.toHaveBeenCalledWith();
    });

    it('emits an error when there is a GraphQL error', async () => {
      const response = {
        data: {
          workItemUpdate: {
            errors: ['Error!'],
            workItem: {},
          },
        },
      };
      createComponent({
        isEditing: true,
        mutationHandler: jest.fn().mockResolvedValue(response),
        canUpdate: true,
      });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('emits an error when there is a network error', async () => {
      createComponent({
        isEditing: true,
        mutationHandler: jest.fn().mockRejectedValue(new Error()),
        canUpdate: true,
      });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('tracks updating the weight', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent({ isEditing: true, canUpdate: true });

      await nextTick();

      findInput().setValue('1');
      findInput().trigger('blur');

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_weight', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_weight',
        property: 'type_Task',
      });
    });
  });
});
