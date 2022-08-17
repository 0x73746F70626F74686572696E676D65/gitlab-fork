import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlDatepicker } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateTimelineEvent from '~/issues/show/components/incidents/create_timeline_event.vue';
import TimelineEventsForm from '~/issues/show/components/incidents/timeline_events_form.vue';
import createTimelineEventMutation from '~/issues/show/components/incidents/graphql/queries/create_timeline_event.mutation.graphql';
import getTimelineEvents from '~/issues/show/components/incidents/graphql/queries/get_timeline_events.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/flash';
import { useFakeDate } from 'helpers/fake_date';
import {
  timelineEventsCreateEventResponse,
  timelineEventsCreateEventError,
  mockGetTimelineData,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/flash');

const fakeDate = '2020-07-08T00:00:00.000Z';

const mockInputData = {
  incidentId: 'gid://gitlab/Issue/1',
  note: 'test',
  occurredAt: '2020-07-08T00:00:00.000Z',
};

describe('Create Timeline events', () => {
  useFakeDate(fakeDate);
  let wrapper;
  let responseSpy;
  let apolloProvider;

  const findSubmitButton = () => wrapper.findByText(__('Save'));
  const findSubmitAndAddButton = () =>
    wrapper.findByText(s__('Incident|Save and add another event'));
  const findCancelButton = () => wrapper.findByText(__('Cancel'));
  const findDatePicker = () => wrapper.findComponent(GlDatepicker);
  const findNoteInput = () => wrapper.findByTestId('input-note');
  const setNoteInput = () => {
    const textarea = findNoteInput().element;
    textarea.value = mockInputData.note;
    textarea.dispatchEvent(new Event('input'));
  };
  const findHourInput = () => wrapper.findByTestId('input-hours');
  const findMinuteInput = () => wrapper.findByTestId('input-minutes');
  const setDatetime = () => {
    const inputDate = new Date(mockInputData.occurredAt);
    findDatePicker().vm.$emit('input', inputDate);
    findHourInput().vm.$emit('input', inputDate.getHours());
    findMinuteInput().vm.$emit('input', inputDate.getMinutes());
  };
  const fillForm = () => {
    setDatetime();
    setNoteInput();
  };

  function createMockApolloProvider() {
    const requestHandlers = [[createTimelineEventMutation, responseSpy]];
    const mockApollo = createMockApollo(requestHandlers);

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getTimelineEvents,
      data: mockGetTimelineData,
      variables: {
        fullPath: 'group/project',
        incidentId: 'gid://gitlab/Issue/1',
      },
    });

    return mockApollo;
  }

  const mountComponent = () => {
    wrapper = mountExtended(CreateTimelineEvent, {
      propsData: {
        hasTimelineEvents: true,
      },
      provide: {
        fullPath: 'group/project',
        issuableId: '1',
      },
      apolloProvider,
    });
  };

  beforeEach(() => {
    responseSpy = jest.fn().mockResolvedValue(timelineEventsCreateEventResponse);
    apolloProvider = createMockApolloProvider();
  });

  afterEach(() => {
    createAlert.mockReset();
    wrapper.destroy();
  });

  describe('createIncidentTimelineEvent', () => {
    const closeFormEvent = { 'hide-new-timeline-events-form': [[]] };

    const expectedData = {
      input: mockInputData,
    };

    beforeEach(() => {
      mountComponent();
      fillForm();
    });

    describe('on submit', () => {
      beforeEach(async () => {
        findSubmitButton().trigger('click');
        await waitForPromises();
      });

      it('should call the mutation with the right variables', () => {
        expect(responseSpy).toHaveBeenCalledWith(expectedData);
      });

      it('should close the form on successful addition', () => {
        expect(wrapper.emitted()).toEqual(closeFormEvent);
      });
    });

    describe('on submit and add', () => {
      beforeEach(async () => {
        findSubmitAndAddButton().trigger('click');
        await waitForPromises();
      });

      it('should keep the form open for save and add another', () => {
        expect(wrapper.emitted()).toEqual({});
      });
    });

    describe('on cancel', () => {
      beforeEach(async () => {
        findCancelButton().trigger('click');
        await waitForPromises();
      });

      it('should close the form', () => {
        expect(wrapper.emitted()).toEqual(closeFormEvent);
      });
    });
  });

  describe('error handling', () => {
    it('should show an error when submission returns an error', async () => {
      const expectedAlertArgs = {
        message: `Error creating incident timeline event: ${timelineEventsCreateEventError.data.timelineEventCreate.errors[0]}`,
      };
      responseSpy.mockResolvedValueOnce(timelineEventsCreateEventError);
      mountComponent();

      findSubmitButton().trigger('click');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(expectedAlertArgs);
    });

    it('should show an error when submission fails', async () => {
      const expectedAlertArgs = {
        captureError: true,
        error: new Error(),
        message: 'Something went wrong while creating the incident timeline event.',
      };
      responseSpy.mockRejectedValueOnce();
      mountComponent();

      findSubmitButton().trigger('click');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(expectedAlertArgs);
    });

    it('should keep the form open on failed addition', async () => {
      responseSpy.mockResolvedValueOnce(timelineEventsCreateEventError);
      mountComponent();

      await wrapper.findComponent(TimelineEventsForm).vm.$emit('save-event', mockInputData);
      await waitForPromises;
      expect(wrapper.emitted()).toEqual({});
    });
  });
});
