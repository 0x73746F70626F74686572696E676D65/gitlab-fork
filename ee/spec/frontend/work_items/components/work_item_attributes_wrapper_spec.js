import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import WorkItemProgress from 'ee/work_items/components/work_item_progress.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemRolledupDates from 'ee/work_items/components/work_item_rolledup_dates.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { workItemResponseFactory, epicType } from 'jest/work_items/mock_data';
import WorkItemParent from '~/work_items/components/work_item_parent.vue';
import WorkItemAttributesWrapper from '~/work_items/components/work_item_attributes_wrapper.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import workItemUpdatedSubscription from '~/work_items/graphql/work_item_updated.subscription.graphql';

describe('EE WorkItemAttributesWrapper component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemQueryResponse = workItemResponseFactory({ canUpdate: true, canDelete: true });

  const successHandler = jest.fn().mockResolvedValue(workItemQueryResponse);
  const workItemUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });

  const findWorkItemIteration = () => wrapper.findComponent(WorkItemIteration);
  const findWorkItemWeight = () => wrapper.findComponent(WorkItemWeight);
  const findWorkItemProgress = () => wrapper.findComponent(WorkItemProgress);
  const findWorkItemColor = () => wrapper.findComponent(WorkItemColor);
  const findWorkItemHealthStatus = () => wrapper.findComponent(WorkItemHealthStatus);
  const findWorkItemRolledupDates = () => wrapper.findComponent(WorkItemRolledupDates);

  const createComponent = ({
    workItem = workItemQueryResponse.data.workItem,
    handler = successHandler,
    confidentialityMock = [updateWorkItemMutation, jest.fn()],
    featureFlags = { workItemsBeta: true, workItemsRolledupDates: true },
    hasSubepicsFeature = true,
  } = {}) => {
    wrapper = shallowMount(WorkItemAttributesWrapper, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, handler],
        [workItemUpdatedSubscription, workItemUpdatedSubscriptionHandler],
        confidentialityMock,
      ]),
      propsData: {
        fullPath: 'group/project',
        workItem,
      },
      provide: {
        hasIssueWeightsFeature: true,
        hasIterationsFeature: true,
        hasOkrsFeature: true,
        hasSubepicsFeature,
        hasIssuableHealthStatusFeature: true,
        projectNamespace: 'namespace',
        glFeatures: featureFlags,
        isGroup: false,
      },
    });
  };

  describe('iteration widget', () => {
    describe.each`
      description                               | iterationWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}                | ${true}
      ${'when widget is not returned from API'} | ${false}               | ${false}
    `('$description', ({ iterationWidgetPresent, exists }) => {
      it(`${
        iterationWidgetPresent ? 'renders' : 'does not render'
      } iteration component`, async () => {
        const response = workItemResponseFactory({ iterationWidgetPresent });
        createComponent({
          workItem: response.data.workItem,
          featureFlags: { workItemsBeta: false },
        });
        await waitForPromises();

        expect(findWorkItemIteration().exists()).toBe(exists);
      });
    });

    it('emits an error event to the wrapper', async () => {
      createComponent({ featureFlags: { workItemsBeta: false } });
      const updateError = 'Failed to update';

      findWorkItemIteration().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual([[updateError]]);
    });
  });

  describe('weight widget', () => {
    describe.each`
      description                               | weightWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}             | ${true}
      ${'when widget is not returned from API'} | ${false}            | ${false}
    `('$description', ({ weightWidgetPresent, exists }) => {
      it(`${weightWidgetPresent ? 'renders' : 'does not render'} weight component`, async () => {
        const response = workItemResponseFactory({ weightWidgetPresent });
        createComponent({ workItem: response.data.workItem });

        await waitForPromises();

        expect(findWorkItemWeight().exists()).toBe(exists);
      });
    });

    it('renders WorkItemWeight', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemWeight().exists()).toBe(true);
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ weightWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      const updateError = 'Failed to update';

      await waitForPromises();

      findWorkItemWeight().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual([[updateError]]);
    });
  });

  describe('health status widget', () => {
    describe.each`
      description                               | healthStatusWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}                   | ${true}
      ${'when widget is not returned from API'} | ${false}                  | ${false}
    `('$description', ({ healthStatusWidgetPresent, exists }) => {
      it(`${
        healthStatusWidgetPresent ? 'renders' : 'does not render'
      } healthStatus component`, () => {
        const response = workItemResponseFactory({ healthStatusWidgetPresent });
        createComponent({ workItem: response.data.workItem });

        expect(findWorkItemHealthStatus().exists()).toBe(exists);
      });
    });

    it('renders WorkItemHealthStatus', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemHealthStatus().exists()).toBe(true);
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ healthStatusWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      const updateError = 'Failed to update';

      findWorkItemHealthStatus().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual([[updateError]]);
    });
  });

  describe('progress widget', () => {
    describe.each`
      description                               | progressWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}               | ${true}
      ${'when widget is not returned from API'} | ${false}              | ${false}
    `('$description', ({ progressWidgetPresent, exists }) => {
      it(`${progressWidgetPresent ? 'renders' : 'does not render'} progress component`, () => {
        const response = workItemResponseFactory({ progressWidgetPresent });
        createComponent({ workItem: response.data.workItem });

        expect(findWorkItemProgress().exists()).toBe(exists);
      });
    });

    it('renders WorkItemProgress', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemProgress().exists()).toBe(true);
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ progressWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      const updateError = 'Failed to update';

      findWorkItemProgress().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual([[updateError]]);
    });
  });

  describe('color widget', () => {
    describe.each`
      description                               | colorWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}            | ${true}
      ${'when widget is not returned from API'} | ${false}           | ${false}
    `('$description', ({ colorWidgetPresent, exists }) => {
      it(`${colorWidgetPresent ? 'renders' : 'does not render'} color component`, () => {
        const response = workItemResponseFactory({ colorWidgetPresent });

        createComponent({ workItem: response.data.workItem });

        expect(findWorkItemColor().exists()).toBe(exists);
      });
    });

    it('renders WorkItemColor', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemColor().exists()).toBe(true);
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ colorWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      const updateError = 'Failed to update';

      findWorkItemColor().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual([[updateError]]);
    });
  });

  describe('parent widget', () => {
    it.each`
      description                                       | hasSubepicsFeature | exists
      ${'renders when subepics is available'}           | ${true}            | ${true}
      ${'does not render when subepics is unavailable'} | ${false}           | ${false}
    `('$description', ({ hasSubepicsFeature, exists }) => {
      const response = workItemResponseFactory({ workItemType: epicType });
      createComponent({ workItem: response.data.workItem, hasSubepicsFeature });

      expect(wrapper.findComponent(WorkItemParent).exists()).toBe(exists);
    });
  });

  describe('rolledup dates widget', () => {
    const createComponentWithRolledupDates = async ({ featureFlag = true } = {}) => {
      const response = workItemResponseFactory({
        rolledupDatesWidgetPresent: true,
        datesWidgetPresent: false,
        workItemType: epicType,
      });

      createComponent({
        workItem: response.data.workItem,
        handler: jest.fn().mockResolvedValue(workItemQueryResponse),
        featureFlags: { workItemsRolledupDates: featureFlag },
      });

      await waitForPromises();
    };

    it.each`
      description                                                              | featureFlag | exists
      ${'renders rolledup dates widget when feature flag is enabled'}          | ${true}     | ${true}
      ${'does not render rolledup dates widget when feature flag is disabled'} | ${false}    | ${false}
    `('$description', async ({ featureFlag, exists }) => {
      await createComponentWithRolledupDates({ featureFlag });

      expect(findWorkItemRolledupDates().exists()).toBe(exists);
    });
  });
});
