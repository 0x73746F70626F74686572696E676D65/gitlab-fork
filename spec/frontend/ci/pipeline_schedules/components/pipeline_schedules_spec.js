import { GlAlert, GlEmptyState, GlLink, GlLoadingIcon, GlPagination, GlTabs } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { trimText } from 'helpers/text_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PipelineSchedules from '~/ci/pipeline_schedules/components/pipeline_schedules.vue';
import DeletePipelineScheduleModal from '~/ci/pipeline_schedules/components/delete_pipeline_schedule_modal.vue';
import TakeOwnershipModal from '~/ci/pipeline_schedules/components/take_ownership_modal.vue';
import PipelineSchedulesTable from '~/ci/pipeline_schedules/components/table/pipeline_schedules_table.vue';
import deletePipelineScheduleMutation from '~/ci/pipeline_schedules/graphql/mutations/delete_pipeline_schedule.mutation.graphql';
import playPipelineScheduleMutation from '~/ci/pipeline_schedules/graphql/mutations/play_pipeline_schedule.mutation.graphql';
import takeOwnershipMutation from '~/ci/pipeline_schedules/graphql/mutations/take_ownership.mutation.graphql';
import getPipelineSchedulesQuery from '~/ci/pipeline_schedules/graphql/queries/get_pipeline_schedules.query.graphql';
import { SCHEDULES_PER_PAGE } from '~/ci/pipeline_schedules/constants';
import {
  mockGetPipelineSchedulesGraphQLResponse,
  mockPipelineScheduleNodes,
  mockPipelineScheduleCurrentUser,
  deleteMutationResponse,
  playMutationResponse,
  takeOwnershipMutationResponse,
  emptyPipelineSchedulesResponse,
  mockPipelineSchedulesResponseWithPagination,
  mockPipelineSchedulesResponsePlanLimitReached,
  noPlanLimitResponse,
} from '../mock_data';

Vue.use(VueApollo);

const $toast = {
  show: jest.fn(),
};

describe('Pipeline schedules app', () => {
  let wrapper;

  const successHandler = jest.fn().mockResolvedValue(mockGetPipelineSchedulesGraphQLResponse);
  const successHandlerWithPagination = jest
    .fn()
    .mockResolvedValue(mockPipelineSchedulesResponseWithPagination);
  const successEmptyHandler = jest.fn().mockResolvedValue(emptyPipelineSchedulesResponse);
  const planLimitReachedHandler = jest
    .fn()
    .mockResolvedValue(mockPipelineSchedulesResponsePlanLimitReached);
  const noPlanLimitHandler = jest.fn().mockResolvedValue(noPlanLimitResponse);
  const failedHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const deleteMutationHandlerSuccess = jest.fn().mockResolvedValue(deleteMutationResponse);
  const deleteMutationHandlerFailed = jest.fn().mockRejectedValue(new Error('GraphQL error'));
  const playMutationHandlerSuccess = jest.fn().mockResolvedValue(playMutationResponse);
  const playMutationHandlerFailed = jest.fn().mockRejectedValue(new Error('GraphQL error'));
  const takeOwnershipMutationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(takeOwnershipMutationResponse);
  const takeOwnershipMutationHandlerFailed = jest
    .fn()
    .mockRejectedValue(new Error('GraphQL error'));

  const createMockApolloProvider = (
    requestHandlers = [[getPipelineSchedulesQuery, successHandler]],
  ) => {
    return createMockApollo(requestHandlers);
  };

  const createComponent = (requestHandlers) => {
    wrapper = mountExtended(PipelineSchedules, {
      provide: {
        fullPath: 'gitlab-org/gitlab',
        newSchedulePath: '/root/ci-project/-/pipeline_schedules/new',
      },
      mocks: {
        $toast,
      },
      apolloProvider: createMockApolloProvider(requestHandlers),
    });
  };

  const findTable = () => wrapper.findComponent(PipelineSchedulesTable);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDeleteModal = () => wrapper.findComponent(DeletePipelineScheduleModal);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTakeOwnershipModal = () => wrapper.findComponent(TakeOwnershipModal);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findLink = () => wrapper.findComponent(GlLink);
  const findPlanLimitReachedAlert = () => wrapper.findByTestId('plan-limit-reached-alert');
  const findNewButton = () => wrapper.findByTestId('new-schedule-button');
  const findAllTab = () => wrapper.findByTestId('pipeline-schedules-all-tab');
  const findActiveTab = () => wrapper.findByTestId('pipeline-schedules-active-tab');
  const findInactiveTab = () => wrapper.findByTestId('pipeline-schedules-inactive-tab');
  const findSchedulesCharacteristics = () =>
    wrapper.findByTestId('pipeline-schedules-characteristics');
  const findPagination = () => wrapper.findComponent(GlPagination);
  const setPage = async (page) => {
    findPagination().vm.$emit('input', page);
    await waitForPromises();
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays table, tabs and new button', async () => {
      await waitForPromises();

      expect(findTable().exists()).toBe(true);
      expect(findNewButton().exists()).toBe(true);
      expect(findTabs().exists()).toBe(true);
      expect(findAlert().exists()).toBe(false);
    });

    it('handles loading state', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('new schedule button links to new schedule path', async () => {
      await waitForPromises();

      expect(findNewButton().attributes('href')).toBe('/root/ci-project/-/pipeline_schedules/new');
      expect(findNewButton().props('disabled')).toBe(false);
    });

    it('does not display pagination when no next page exists', () => {
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('fetching pipeline schedules', () => {
    it('fetches query and passes an array of pipeline schedules', async () => {
      createComponent();

      expect(successHandler).toHaveBeenCalled();

      await waitForPromises();

      expect(findTable().props('schedules')).toEqual(mockPipelineScheduleNodes);
      expect(findTable().props('currentUser')).toEqual(mockPipelineScheduleCurrentUser);
    });

    it('shows query error alert', async () => {
      createComponent([[getPipelineSchedulesQuery, failedHandler]]);

      await waitForPromises();

      expect(findAlert().text()).toBe('There was a problem fetching pipeline schedules.');
    });
  });

  describe('deleting a pipeline schedule', () => {
    it('shows delete mutation error alert', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [deletePipelineScheduleMutation, deleteMutationHandlerFailed],
      ]);

      await waitForPromises();

      findDeleteModal().vm.$emit('deleteSchedule');

      await waitForPromises();

      expect(findAlert().text()).toBe('There was a problem deleting the pipeline schedule.');
    });

    it('deletes pipeline schedule and refetches query', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [deletePipelineScheduleMutation, deleteMutationHandlerSuccess],
      ]);

      await waitForPromises();

      const scheduleId = mockPipelineScheduleNodes[0].id;

      findTable().vm.$emit('showDeleteModal', scheduleId);

      expect(successHandler).toHaveBeenCalledTimes(1);

      findDeleteModal().vm.$emit('deleteSchedule');

      await waitForPromises();

      expect(deleteMutationHandlerSuccess).toHaveBeenCalledWith({
        id: scheduleId,
      });
      expect(successHandler).toHaveBeenCalledTimes(2);
      expect($toast.show).toHaveBeenCalledWith('Pipeline schedule successfully deleted.');
    });

    it('handles delete modal visibility correctly', async () => {
      createComponent();

      await waitForPromises();

      expect(findDeleteModal().props('visible')).toBe(false);

      findTable().vm.$emit('showDeleteModal', mockPipelineScheduleNodes[0].id);

      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(true);
      expect(findTakeOwnershipModal().props('visible')).toBe(false);

      findDeleteModal().vm.$emit('hideModal');

      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(false);
    });
  });

  describe('playing a pipeline schedule', () => {
    it('shows play mutation error alert', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [playPipelineScheduleMutation, playMutationHandlerFailed],
      ]);

      await waitForPromises();

      findTable().vm.$emit('playPipelineSchedule');

      await waitForPromises();

      expect(findAlert().text()).toBe('There was a problem playing the pipeline schedule.');
    });

    it('plays pipeline schedule', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [playPipelineScheduleMutation, playMutationHandlerSuccess],
      ]);

      await waitForPromises();

      const scheduleId = mockPipelineScheduleNodes[0].id;

      findTable().vm.$emit('playPipelineSchedule', scheduleId);

      await waitForPromises();

      expect(playMutationHandlerSuccess).toHaveBeenCalledWith({
        id: scheduleId,
      });
      expect(findAlert().text()).toBe(
        'Successfully scheduled a pipeline to run. Go to the Pipelines page for details.',
      );
    });
  });

  describe('taking ownership of a pipeline schedule', () => {
    it('shows take ownership mutation error alert', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [takeOwnershipMutation, takeOwnershipMutationHandlerFailed],
      ]);

      await waitForPromises();

      findTakeOwnershipModal().vm.$emit('takeOwnership');

      await waitForPromises();

      expect(findAlert().text()).toBe(
        'There was a problem taking ownership of the pipeline schedule.',
      );
    });

    it('takes ownership of pipeline schedule and refetches query', async () => {
      createComponent([
        [getPipelineSchedulesQuery, successHandler],
        [takeOwnershipMutation, takeOwnershipMutationHandlerSuccess],
      ]);

      await waitForPromises();

      const scheduleId = mockPipelineScheduleNodes[1].id;

      findTable().vm.$emit('showTakeOwnershipModal', scheduleId);

      expect(successHandler).toHaveBeenCalledTimes(1);

      findTakeOwnershipModal().vm.$emit('takeOwnership');

      await waitForPromises();

      expect(takeOwnershipMutationHandlerSuccess).toHaveBeenCalledWith({
        id: scheduleId,
      });
      expect(successHandler).toHaveBeenCalledTimes(2);
      expect($toast.show).toHaveBeenCalledWith('Successfully taken ownership from Admin.');
    });

    it('handles take ownership modal visibility correctly', async () => {
      createComponent();

      await waitForPromises();

      expect(findTakeOwnershipModal().props('visible')).toBe(false);

      findTable().vm.$emit('showTakeOwnershipModal', mockPipelineScheduleNodes[0].id);

      await nextTick();

      expect(findTakeOwnershipModal().props('visible')).toBe(true);
      expect(findDeleteModal().props('visible')).toBe(false);

      findTakeOwnershipModal().vm.$emit('hideModal');

      await nextTick();

      expect(findTakeOwnershipModal().props('visible')).toBe(false);
    });
  });

  describe('pipeline schedule tabs', () => {
    beforeEach(async () => {
      createComponent([[getPipelineSchedulesQuery, successHandler]]);

      await waitForPromises();
    });

    it('displays All tab with count', () => {
      expect(trimText(findAllTab().text())).toBe(`All ${mockPipelineScheduleNodes.length}`);
    });

    it('displays Active tab with no count', () => {
      expect(findActiveTab().text()).toBe('Active');
    });

    it('displays Inactive tab with no count', () => {
      expect(findInactiveTab().text()).toBe('Inactive');
    });

    it('should refetch the schedules query on a tab click', async () => {
      expect(successHandler).toHaveBeenCalledTimes(1);

      await findAllTab().trigger('click');

      expect(successHandler).toHaveBeenCalledTimes(3);
    });

    it('all tab click should not send scope value with query', async () => {
      findAllTab().trigger('click');

      await nextTick();

      expect(successHandler).toHaveBeenCalledWith({
        ids: null,
        projectPath: 'gitlab-org/gitlab',
        status: null,
        first: SCHEDULES_PER_PAGE,
        last: null,
        nextPageCursor: '',
        prevPageCursor: '',
      });
    });
  });

  describe('Empty pipeline schedules response', () => {
    it('should show an empty state', async () => {
      createComponent([[getPipelineSchedulesQuery, successEmptyHandler]]);

      await waitForPromises();

      const schedulesCharacteristics = findSchedulesCharacteristics();

      expect(findEmptyState().exists()).toBe(true);
      expect(schedulesCharacteristics.text()).toContain('Runs for a specific branch or tag.');
      expect(schedulesCharacteristics.text()).toContain('Can have custom CI/CD variables.');
      expect(schedulesCharacteristics.text()).toContain(
        'Runs with the same project permissions as the schedule owner.',
      );

      expect(findLink().exists()).toBe(true);
      expect(findLink().text()).toContain('scheduled pipelines documentation.');
    });

    describe('inactive tab', () => {
      beforeEach(() => {
        setWindowLocation('https://gitlab.com/flightjs/Flight/-/pipeline_schedules?scope=INACTIVE');
      });

      it('should not show empty state', async () => {
        createComponent([[getPipelineSchedulesQuery, successEmptyHandler]]);

        await waitForPromises();

        expect(findEmptyState().exists()).toBe(false);
      });
    });
  });

  describe('pagination', () => {
    const { pageInfo } = mockPipelineSchedulesResponseWithPagination.data.project.pipelineSchedules;

    beforeEach(async () => {
      createComponent([[getPipelineSchedulesQuery, successHandlerWithPagination]]);

      await waitForPromises();
    });

    it('displays pagination', () => {
      expect(findPagination().exists()).toBe(true);
      expect(findPagination().props()).toMatchObject({
        value: 1,
        prevPage: Number(pageInfo.hasPreviousPage),
        nextPage: Number(pageInfo.hasNextPage),
      });
      expect(successHandlerWithPagination).toHaveBeenCalledWith({
        projectPath: 'gitlab-org/gitlab',
        ids: null,
        first: SCHEDULES_PER_PAGE,
        last: null,
        nextPageCursor: '',
        prevPageCursor: '',
      });
    });

    it('updates query variables when going to next page', async () => {
      await setPage(2);

      expect(successHandlerWithPagination).toHaveBeenCalledWith({
        projectPath: 'gitlab-org/gitlab',
        ids: null,
        first: SCHEDULES_PER_PAGE,
        last: null,
        prevPageCursor: '',
        nextPageCursor: pageInfo.endCursor,
      });
      expect(findPagination().props('value')).toEqual(2);
    });

    it('when switching tabs pagination should reset', async () => {
      await setPage(2);

      expect(findPagination().props('value')).toEqual(2);

      await findInactiveTab().trigger('click');

      await waitForPromises();

      expect(findPagination().props('value')).toEqual(1);
    });
  });

  describe('plan limit reached', () => {
    beforeEach(async () => {
      createComponent([[getPipelineSchedulesQuery, planLimitReachedHandler]]);

      await waitForPromises();
    });

    it('shows disabled new schedule button with alert', () => {
      expect(findNewButton().props('disabled')).toBe(true);
      expect(findPlanLimitReachedAlert().exists()).toBe(true);
    });
  });

  describe('no plan limit', () => {
    beforeEach(async () => {
      createComponent([[getPipelineSchedulesQuery, noPlanLimitHandler]]);

      await waitForPromises();
    });

    it('shows disabled new schedule button', () => {
      expect(findNewButton().props('disabled')).toBe(true);
      expect(findPlanLimitReachedAlert().exists()).toBe(false);
    });
  });
});
