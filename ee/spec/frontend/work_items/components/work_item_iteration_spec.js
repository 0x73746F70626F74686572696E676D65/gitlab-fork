import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import projectIterationsQuery from 'ee/work_items/graphql/project_iterations.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  groupIterationsResponse,
  groupIterationsResponseWithNoIterations,
  mockIterationWidgetResponse,
  updateWorkItemMutationErrorResponse,
  updateWorkItemMutationResponse,
} from 'jest/work_items/mock_data';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';

describe('WorkItemIteration component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const workItemType = 'Task';

  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);

  const successSearchQueryHandler = jest.fn().mockResolvedValue(groupIterationsResponse);
  const successSearchWithNoMatchingIterations = jest
    .fn()
    .mockResolvedValue(groupIterationsResponseWithNoIterations);
  const successUpdateWorkItemMutationHandler = jest
    .fn()
    .mockResolvedValue(updateWorkItemMutationResponse);

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('dropdownShown');
  };

  const createComponent = ({
    mountFn = shallowMountExtended,
    canUpdate = true,
    iteration = mockIterationWidgetResponse,
    searchQueryHandler = successSearchQueryHandler,
    mutationHandler = successUpdateWorkItemMutationHandler,
  } = {}) => {
    wrapper = mountFn(WorkItemIteration, {
      apolloProvider: createMockApollo([
        [projectIterationsQuery, searchQueryHandler],
        [updateWorkItemMutation, mutationHandler],
      ]),
      propsData: {
        canUpdate,
        fullPath: 'test-project-path',
        iteration,
        workItemId,
        workItemType,
      },
      provide: {
        hasIterationsFeature: true,
      },
    });
  };

  it('has "Iteration" label', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe('Iteration');
  });

  describe('Default text with canUpdate false and iteration value', () => {
    describe.each`
      description             | iteration                      | value
      ${'when no iteration'}  | ${null}                        | ${'None'}
      ${'when iteration set'} | ${mockIterationWidgetResponse} | ${mockIterationWidgetResponse.title}
    `('$description', ({ iteration, value }) => {
      it(`has a value of "${value}"`, () => {
        createComponent({ mountFn: mountExtended, canUpdate: false, iteration });

        expect(wrapper.text()).toContain(value);
        expect(findSidebarDropdownWidget().props('canUpdate')).toBe(false);
      });
    });
  });

  describe('Dropdown search', () => {
    it('shows no items in the dropdown when no results matching', () => {
      createComponent({ searchQueryHandler: successSearchWithNoMatchingIterations });

      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(0);
    });
  });

  describe('Dropdown options', () => {
    beforeEach(() => {
      createComponent({ canUpdate: true });
    });

    it('calls successSearchQueryHandler with variables when dropdown is opened', async () => {
      showDropdown();
      await waitForPromises();

      expect(successSearchQueryHandler).toHaveBeenCalledWith({
        fullPath: 'test-project-path',
        state: 'opened',
        title: '',
      });
    });

    it('shows the skeleton loader when the items are being fetched on click', async () => {
      showDropdown();

      await nextTick();

      expect(findSidebarDropdownWidget().props('loading')).toBe(true);
    });

    it('shows the iterations in dropdown when the items have finished fetching', async () => {
      showDropdown();

      await waitForPromises();

      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(
        groupIterationsResponse.data.workspace.attributes.nodes.length,
      );
    });

    it('changes the iteration to null on reset/clear', async () => {
      findSidebarDropdownWidget().vm.$emit('updateValue', null);
      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);

      await waitForPromises();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(false);
    });

    it('changes the iteration to the selected iteration', async () => {
      const iterationAtIndex = groupIterationsResponse.data.workspace.attributes.nodes[0];

      findSidebarDropdownWidget().vm.$emit('updateValue', iterationAtIndex.id);
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('itemValue')).toBe(iterationAtIndex.id);
    });
  });

  describe('Error handlers', () => {
    it.each`
      errorType          | expectedErrorMessage                                                 | mockValue                              | resolveFunction
      ${'graphql error'} | ${'Something went wrong while updating the task. Please try again.'} | ${updateWorkItemMutationErrorResponse} | ${'mockResolvedValue'}
      ${'network error'} | ${'Something went wrong while updating the task. Please try again.'} | ${new Error()}                         | ${'mockRejectedValue'}
    `(
      'emits an error when there is a $errorType',
      async ({ mockValue, expectedErrorMessage, resolveFunction }) => {
        createComponent({
          mutationHandler: jest.fn()[resolveFunction](mockValue),
          canUpdate: true,
        });

        findSidebarDropdownWidget().vm.$emit('updateValue', null);
        await waitForPromises();

        expect(wrapper.emitted('error')).toEqual([[expectedErrorMessage]]);
      },
    );
  });

  describe('Tracking event', () => {
    it('tracks updating the iteration', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent({ canUpdate: true });

      findSidebarDropdownWidget().vm.$emit('updateValue', null);
      await waitForPromises();

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_iteration', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_iteration',
        property: 'type_Task',
      });
    });
  });
});
