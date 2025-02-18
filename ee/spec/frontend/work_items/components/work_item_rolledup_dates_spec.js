import { GlDatepicker, GlFormRadio } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { Mousetrap } from '~/lib/mousetrap';
import WorkItemRolledupDates from 'ee/work_items/components/work_item_rolledup_dates.vue';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import {
  updateWorkItemMutationResponse,
  updateWorkItemMutationErrorResponse,
} from 'jest/work_items/mock_data';

Vue.use(VueApollo);

const DUE_DATE_INHERITED = '2024-12-31';
const DUE_DATE_FIXED = '2024-11-30';
const START_DATE_INHERITED = '2021-01-01';
const START_DATE_FIXED = '2021-12-31';

function parseDate(dateString) {
  return new Date(dateString).toISOString().split('T')[0];
}

describe('WorkItemRolledupDates component', () => {
  let wrapper;

  const startDateShowSpy = jest.fn();

  const workItemId = 'gid://gitlab/WorkItem/1';
  const updateWorkItemMutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);

  const findStartDatePicker = () => wrapper.findComponent({ ref: 'startDatePicker' });
  const findDueDatePicker = () => wrapper.findByTestId('due-date-picker');
  const findApplyButton = () => wrapper.findByTestId('apply-button');
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDatepickerWrapper = () => wrapper.findByTestId('datepicker-wrapper');
  const findStartDateValue = () => wrapper.findByTestId('start-date-value');
  const findDueDateValue = () => wrapper.findByTestId('due-date-value');
  const findFixedRadioButton = () => wrapper.findAllComponents(GlFormRadio).at(0);
  const findInheritedRadioButton = () => wrapper.findAllComponents(GlFormRadio).at(1);

  const createComponent = ({
    canUpdate = false,
    dueDateFixed = null,
    startDateFixed = null,
    dueDateInherited = null,
    startDateInherited = null,
    dueDateIsFixed = false,
    startDateIsFixed = false,
    mutationHandler = updateWorkItemMutationHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemRolledupDates, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        dueDateIsFixed,
        startDateIsFixed,
        dueDateFixed,
        startDateFixed,
        dueDateInherited,
        startDateInherited,
        workItemType: 'Epic',
        workItem: updateWorkItemMutationResponse.data.workItemUpdate.workItem,
      },
      provide: {
        isGroup: false,
      },
      stubs: {
        GlDatepicker: stubComponent(GlDatepicker, {
          methods: {
            show: startDateShowSpy,
          },
        }),
        GlFormRadio,
      },
    });
  };

  describe('when in default state', () => {
    describe('start date', () => {
      it('is rendered correctly when it is passed to the component', () => {
        createComponent({ startDateInherited: '2022-01-01' });

        expect(findStartDateValue().text()).toBe('Jan 1, 2022');
        expect(findStartDateValue().classes('gl-text-secondary')).toBe(false);
      });

      it('renders `None` when it is  not passed to the component`', () => {
        createComponent();

        expect(findStartDateValue().text()).toBe('None');
        expect(findStartDateValue().classes('gl-text-secondary')).toBe(true);
      });
    });

    describe('end date', () => {
      it('is rendered correctly when it is passed to the component', () => {
        createComponent({ dueDateInherited: '2022-01-01' });

        expect(findDueDateValue().text()).toContain('Jan 1, 2022');
        expect(findDueDateValue().classes('gl-text-secondary')).toBe(false);
      });

      it('renders `None` when it is  not passed to the component`', () => {
        createComponent();

        expect(findDueDateValue().text()).toContain('None');
        expect(findDueDateValue().classes('gl-text-secondary')).toBe(true);
      });
    });

    it('does not render datepickers', () => {
      createComponent();

      expect(findStartDatePicker().exists()).toBe(false);
      expect(findDueDatePicker().exists()).toBe(false);
    });

    it('does not render edit button when user cannot update work item', () => {
      createComponent();

      expect(findEditButton().exists()).toBe(false);
    });

    it('renders edit button when user can update work item', () => {
      createComponent({ canUpdate: true });

      expect(findEditButton().exists()).toBe(true);
    });

    it('expands the widget when edit button is clicked', async () => {
      createComponent({ canUpdate: true });
      findEditButton().vm.$emit('click');
      await nextTick();

      expect(findDatepickerWrapper().exists()).toBe(true);
      expect(findStartDateValue().exists()).toBe(false);
      expect(findDueDateValue().exists()).toBe(false);
    });

    describe('when both start and due date are fixed', () => {
      it('checks "fixed" radio button', async () => {
        createComponent({ dueDateIsFixed: true, startDateIsFixed: true });

        await nextTick();

        expect(findFixedRadioButton().props('checked')).toBe('fixed');
      });
    });

    describe('when both start and due date are inherited', () => {
      it('checks "inherited" radio button', async () => {
        createComponent({ dueDateIsFixed: false, startDateIsFixed: false });

        await nextTick();

        expect(findInheritedRadioButton().props('checked')).toBe('inherited');
      });
    });

    describe('when start date is fixed and has value and due date is inherited', () => {
      beforeEach(async () => {
        createComponent({
          dueDateIsFixed: false,
          startDateIsFixed: true,
          startDateFixed: START_DATE_FIXED,
          dueDate: DUE_DATE_INHERITED,
        });

        await nextTick();
      });

      it('checks "fixed" radio button', () => {
        expect(findFixedRadioButton().props('checked')).toBe('fixed');
      });

      it('sets startDate to the fixed value', () => {
        expect(parseDate(findStartDateValue().text())).toBe(START_DATE_FIXED);
      });

      it('sets dueDate to null, ignoring the inherited value', () => {
        expect(findDueDateValue().text()).toBe('None');
      });
    });

    describe('when start date is fixed but has no value and due date is inherited', () => {
      beforeEach(async () => {
        createComponent({
          dueDateIsFixed: false,
          startDateIsFixed: true,
          startDateFixed: null,
          dueDateInherited: DUE_DATE_INHERITED,
        });

        await nextTick();
      });

      it('checks "inherited" radio button', () => {
        expect(findInheritedRadioButton().props('checked')).toBe('inherited');
      });

      it('sets startDate to null', () => {
        expect(findStartDateValue().text()).toBe('None');
      });

      it('sets dueDate to the inherited value', () => {
        expect(parseDate(findDueDateValue().text())).toBe(DUE_DATE_INHERITED);
      });
    });

    describe('when due date is fixed and has value and start date is inherited', () => {
      beforeEach(async () => {
        createComponent({
          dueDateIsFixed: true,
          startDateIsFixed: false,
          dueDateFixed: DUE_DATE_FIXED,
          startDate: START_DATE_INHERITED,
        });

        await nextTick();
      });

      it('checks "fixed" radio button', () => {
        expect(findFixedRadioButton().props('checked')).toBe('fixed');
      });

      it('sets dueDate to the fixed value', () => {
        expect(parseDate(findDueDateValue().text())).toBe(DUE_DATE_FIXED);
      });

      it('sets startDate to null, ignoring the inherited value', () => {
        expect(findStartDateValue().text()).toBe('None');
      });
    });

    describe('when due date is fixed but has no value and start date is inherited', () => {
      beforeEach(async () => {
        createComponent({
          dueDateIsFixed: true,
          startDateIsFixed: false,
          dueDateFixed: null,
          startDateInherited: START_DATE_INHERITED,
        });

        await nextTick();
      });

      it('checks "inherited" radio button', () => {
        expect(findInheritedRadioButton().props('checked')).toBe('inherited');
      });

      it('sets dueDate to null', () => {
        expect(findDueDateValue().text()).toBe('None');
      });

      it('sets startDate to the inherited value', () => {
        expect(parseDate(findStartDateValue().text())).toBe(START_DATE_INHERITED);
      });
    });
  });

  describe.each`
    radioType      | findRadioButton             | isFixed
    ${'fixed'}     | ${findFixedRadioButton}     | ${true}
    ${'inherited'} | ${findInheritedRadioButton} | ${false}
  `('$radioType radio button', ({ radioType, findRadioButton, isFixed }) => {
    it('renders as enabled when user can update work item', () => {
      createComponent({ canUpdate: true });

      expect(findRadioButton().attributes('disabled')).toBeUndefined();
    });

    it('renders as disabled when user cannot update work item', () => {
      createComponent();

      expect(findRadioButton().attributes('disabled')).toBe('true');
    });

    describe('when clicked', () => {
      let trackingSpy;

      beforeEach(async () => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

        createComponent({ canUpdate: true, dueDateIsFixed: isFixed, startDateIsFixed: isFixed });

        findRadioButton().vm.$emit('change');
        await nextTick();
      });

      it(`calls mutation to update rollup type to ${radioType}`, () => {
        expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            rolledupDatesWidget: { dueDateIsFixed: isFixed, startDateIsFixed: isFixed },
          },
        });
      });

      it('tracks updating the rollup type', () => {
        expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_rollup_type', {
          category: TRACKING_CATEGORY_SHOW,
          label: 'item_rolledup_dates',
          property: 'type_Epic',
        });
      });
    });
  });

  describe('when in editing state', () => {
    it('collapses the widget when apply button is clicked', async () => {
      createComponent({ canUpdate: true });
      findEditButton().vm.$emit('click');
      await nextTick();

      findApplyButton().vm.$emit('click');
      await nextTick();

      expect(findDatepickerWrapper().exists()).toBe(false);
    });

    it('updates datepicker props when component startDate and dueDate props are updated', async () => {
      createComponent({ canUpdate: true });
      findEditButton().vm.$emit('click');
      await nextTick();

      expect(findStartDatePicker().props('value')).toBe(null);
      expect(findDueDatePicker().props('value')).toBe(null);

      await wrapper.setProps({
        startDateInherited: '2022-01-01',
        dueDateInherited: '2022-01-02',
      });

      expect(findStartDatePicker().props('value')).toEqual(new Date('2022-01-01'));
      expect(findDueDatePicker().props('value')).toEqual(new Date('2022-01-02'));
    });

    describe('start date picker', () => {
      beforeEach(() => {
        createComponent({
          canUpdate: true,
          dueDateInherited: '2022-01-02',
          startDateInherited: '2022-01-02',
        });

        findEditButton().vm.$emit('click');
        return nextTick();
      });

      it('clears the start date input on `clear` event', async () => {
        findStartDatePicker().vm.$emit('clear');
        await nextTick();

        expect(findStartDatePicker().props('value')).toBe(null);
      });

      describe('when the start date is later than the due date', () => {
        const startDate = new Date('2030-01-01T00:00:00.000Z');

        it('updates the due date picker to the same date', async () => {
          findStartDatePicker().vm.$emit('input', startDate);
          findStartDatePicker().vm.$emit('close');
          await nextTick();

          expect(findDueDatePicker().props('value')).toEqual(startDate);
        });
      });
    });

    describe('when updating date', () => {
      describe('when dates are changed', () => {
        let trackingSpy;

        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDateInherited: '2022-12-31',
            startDateInherited: '2022-12-31',
          });
          trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

          findEditButton().vm.$emit('click');
          await nextTick();

          findStartDatePicker().vm.$emit('input', new Date('2022-01-01T00:00:00.000Z'));
          findStartDatePicker().vm.$emit('close');

          await nextTick();
          findApplyButton().vm.$emit('click');
        });

        it('mutation is called to update dates', () => {
          expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: workItemId,
              rolledupDatesWidget: {
                dueDateFixed: new Date('2022-12-31T00:00:00.000Z'),
                startDateFixed: new Date('2022-01-01T00:00:00.000Z'),
                dueDateIsFixed: true,
                startDateIsFixed: true,
              },
            },
          });
        });

        it('edit button is disabled when mutation is in flight', () => {
          expect(findEditButton().props('disabled')).toBe(true);
        });

        it('edit button is enabled after mutation is resolved', async () => {
          await waitForPromises();
          expect(findEditButton().props('disabled')).toBe(false);
        });

        it('tracks updating the dates', () => {
          expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_dates', {
            category: TRACKING_CATEGORY_SHOW,
            label: 'item_rolledup_dates',
            property: 'type_Epic',
          });
        });
      });

      describe('when dates are unchanged', () => {
        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDateInherited: '2022-12-31',
            startDateInherited: '2022-12-31',
          });

          findEditButton().vm.$emit('click');
          await nextTick();

          findStartDatePicker().vm.$emit('input', new Date('2022-12-31T00:00:00.000Z'));
          findStartDatePicker().vm.$emit('close');

          await nextTick();
          findApplyButton().vm.$emit('click');
        });

        it('mutation is not called to update dates', () => {
          expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
        });
      });

      describe.each`
        description                        | mutationHandler
        ${'when there is a GraphQL error'} | ${jest.fn().mockResolvedValue(updateWorkItemMutationErrorResponse)}
        ${'when there is a network error'} | ${jest.fn().mockRejectedValue(new Error())}
      `('$description', ({ mutationHandler }) => {
        beforeEach(async () => {
          createComponent({
            canUpdate: true,
            dueDateInherited: '2022-12-31',
            startDateInherited: '2022-12-31',
            mutationHandler,
          });

          findEditButton().vm.$emit('click');
          await nextTick();

          findStartDatePicker().vm.$emit('input', new Date('2022-01-01T00:00:00.000Z'));
          findStartDatePicker().vm.$emit('close');

          await nextTick();
          findApplyButton().vm.$emit('click');
          return waitForPromises();
        });

        it('emits an error', () => {
          expect(wrapper.emitted('error')).toEqual([
            ['Something went wrong while updating the epic. Please try again.'],
          ]);
        });
      });
    });

    describe('when escape key is pressed', () => {
      beforeEach(async () => {
        createComponent({
          canUpdate: true,
          dueDate: '2022-12-31',
          startDate: '2022-12-31',
        });

        findEditButton().vm.$emit('click');
        await nextTick();

        findStartDatePicker().vm.$emit('input', new Date('2022-01-01T00:00:00.000Z'));
      });

      it('widget is closed and dates are updated, when date picker is focused', async () => {
        findStartDatePicker().trigger('keydown.esc');
        await nextTick();

        expect(updateWorkItemMutationHandler).toHaveBeenCalled();
        expect(findStartDatePicker().exists()).toBe(false);
      });

      it('widget is closed and dates are updated, when date picker is not focused', async () => {
        findStartDatePicker().trigger('blur');
        Mousetrap.trigger('esc');
        await nextTick();

        expect(updateWorkItemMutationHandler).toHaveBeenCalled();
        expect(findStartDatePicker().exists()).toBe(false);
      });
    });
  });
});
