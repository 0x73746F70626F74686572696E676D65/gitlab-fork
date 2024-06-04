import { GlBadge } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import {
  HEALTH_STATUS_AT_RISK,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_NEEDS_ATTENTION,
  HEALTH_STATUS_ON_TRACK,
  healthStatusTextMap,
} from 'ee/sidebar/constants';

import {
  updateWorkItemMutationResponse,
  workItemByIidResponseFactory,
} from 'jest/work_items/mock_data';

describe('WorkItemHealthStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const workItemType = 'Task';
  const workItemQueryResponse = workItemByIidResponseFactory({ canUpdate: true, canDelete: true });
  const workItemQueryHandler = jest.fn().mockResolvedValue(workItemQueryResponse);

  const findHeader = () => wrapper.find('h3');
  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);
  const findBadge = () => wrapper.findComponent(GlBadge);

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('dropdownShown');
  };

  const createComponent = ({
    canUpdate = true,
    hasIssuableHealthStatusFeature = true,
    healthStatus,
    mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse),
    isGroup = false,
  } = {}) => {
    wrapper = mountExtended(WorkItemHealthStatus, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, workItemQueryHandler],
        [updateWorkItemMutation, mutationHandler],
      ]),
      propsData: {
        canUpdate,
        healthStatus,
        workItemId,
        workItemIid: '1',
        workItemType,
      },
      provide: {
        hasIssuableHealthStatusFeature,
        isGroup,
      },
    });
  };

  it('has "Health status" label for single select', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe('Health status');
  });

  it('the dropdown is not searchable', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('searchable')).toBe(false);
  });

  describe('`hasIssuableHealthStatusFeature` licensed feature', () => {
    describe.each`
      description             | hasIssuableHealthStatusFeature | exists
      ${'when available'}     | ${true}                        | ${true}
      ${'when not available'} | ${false}                       | ${false}
    `('$description', ({ hasIssuableHealthStatusFeature, exists }) => {
      it(`${hasIssuableHealthStatusFeature ? 'renders' : 'does not render'} component`, () => {
        createComponent({ hasIssuableHealthStatusFeature });

        expect(findHeader().exists()).toBe(exists);
      });
    });
  });

  describe('Dropdown options', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the health status options in dropdown', async () => {
      showDropdown();

      await nextTick();

      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(3);
    });
  });

  describe('health status input', () => {
    it.each`
      selected            | expectedStatus
      ${'onTrack'}        | ${'onTrack'}
      ${'needsAttention'} | ${'needsAttention'}
      ${'atRisk'}         | ${'atRisk'}
    `(
      'calls mutation with health status = "$expectedStatus"',
      async ({ selected, expectedStatus }) => {
        const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
        await createComponent({
          mutationHandler: mutationSpy,
        });

        showDropdown();
        await findSidebarDropdownWidget().vm.$emit('updateValue', selected);

        expect(mutationSpy).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            healthStatusWidget: {
              healthStatus: expectedStatus,
            },
          },
        });
      },
    );

    it('changes the health status to null when clicked on Clear', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      await createComponent({ healthStatus: HEALTH_STATUS_ON_TRACK, mutationHandler: mutationSpy });
      showDropdown();
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', null);

      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);

      await waitForPromises();
      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(false);
      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          healthStatusWidget: {
            healthStatus: null,
          },
        },
      });
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
      await createComponent({
        mutationHandler: jest.fn().mockResolvedValue(response),
      });

      showDropdown();

      await findSidebarDropdownWidget().vm.$emit('updateValue', HEALTH_STATUS_ON_TRACK);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('emits an error when there is a network error', async () => {
      await createComponent({
        mutationHandler: jest.fn().mockRejectedValue(new Error()),
      });

      showDropdown();
      await findSidebarDropdownWidget().vm.$emit('updateValue', HEALTH_STATUS_ON_TRACK);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('tracks updating the health status', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      await createComponent({ isEditing: true });

      showDropdown();
      await findSidebarDropdownWidget().vm.$emit('updateValue', HEALTH_STATUS_ON_TRACK);

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_health_status', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: 'type_Task',
      });
    });
  });
  describe('health status rendering', () => {
    describe('correct text', () => {
      it.each`
        healthStatus                     | text
        ${HEALTH_STATUS_ON_TRACK}        | ${healthStatusTextMap[HEALTH_STATUS_ON_TRACK]}
        ${HEALTH_STATUS_NEEDS_ATTENTION} | ${healthStatusTextMap[HEALTH_STATUS_NEEDS_ATTENTION]}
        ${HEALTH_STATUS_AT_RISK}         | ${healthStatusTextMap[HEALTH_STATUS_AT_RISK]}
        ${null}                          | ${HEALTH_STATUS_I18N_NONE}
      `('renders "$text" when health status = "$healthStatus"', ({ healthStatus, text }) => {
        createComponent({ healthStatus });

        expect(wrapper.text()).toContain(text);
      });
    });

    describe('badge renders correct variant', () => {
      it.each`
        healthStatus                     | variant
        ${HEALTH_STATUS_ON_TRACK}        | ${'success'}
        ${HEALTH_STATUS_NEEDS_ATTENTION} | ${'warning'}
        ${HEALTH_STATUS_AT_RISK}         | ${'danger'}
      `('uses "$variant" when health status = "$healthStatus"', ({ healthStatus, variant }) => {
        createComponent({ healthStatus });

        expect(findBadge().props('variant')).toBe(variant);
      });
    });
  });
});
