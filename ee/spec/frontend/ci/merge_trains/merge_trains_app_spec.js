import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import MergeTrainsApp from 'ee/ci/merge_trains/merge_trains_app.vue';
import MergeTrainBranchSelector from 'ee/ci/merge_trains/components/merge_train_branch_selector.vue';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';
import getActiveMergeTrainsQuery from 'ee/ci/merge_trains/graphql/queries/get_active_merge_trains.query.graphql';
import getCompletedMergeTrainsQuery from 'ee/ci/merge_trains/graphql/queries/get_completed_merge_trains.query.graphql';
import { activeTrain, mergedTrain } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('MergeTrainsApp', () => {
  let wrapper;

  const activeTrainsHandler = jest.fn().mockResolvedValue(activeTrain);
  const mergedTrainsHandler = jest.fn().mockResolvedValue(mergedTrain);
  const errorHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const defaultHandlers = [
    [getActiveMergeTrainsQuery, activeTrainsHandler],
    [getCompletedMergeTrainsQuery, mergedTrainsHandler],
  ];

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = (handlers = defaultHandlers) => {
    wrapper = shallowMountExtended(MergeTrainsApp, {
      provide: {
        fullPath: 'namespace/project',
        defaultBranch: 'master',
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  const findBranchSelector = () => wrapper.findComponent(MergeTrainBranchSelector);
  const findTabs = () => wrapper.findComponent(MergeTrainTabs);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findActiveTable = () => wrapper.findByTestId('active-merge-trains-table');
  const findCompletedTable = () => wrapper.findByTestId('completed-merge-trains-table');

  describe('loading', () => {
    it('shows loading icon', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTabs().exists()).toBe(false);
      expect(findActiveTable().exists()).toBe(false);
      expect(findCompletedTable().exists()).toBe(false);
      expect(findBranchSelector().exists()).toBe(false);
    });
  });

  describe('defaults', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders merge train tabs', () => {
      expect(findTabs().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the merge trains tables', () => {
      expect(findActiveTable().exists()).toBe(true);
      expect(findCompletedTable().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the merge train branch filter', () => {
      expect(findBranchSelector().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('calls queries with correct variables', () => {
      const expectedVariables = {
        fullPath: 'namespace/project',
        targetBranch: 'master',
        after: null,
        before: null,
        first: 20,
        last: null,
      };

      expect(activeTrainsHandler).toHaveBeenCalledWith(expectedVariables);
      expect(mergedTrainsHandler).toHaveBeenCalledWith({
        status: 'COMPLETED',
        ...expectedVariables,
      });
    });
  });

  describe('events', () => {
    it('refetches queries on the branchChanged event', async () => {
      createComponent();

      await waitForPromises();

      findBranchSelector().vm.$emit('branchChanged', 'feature-branch');

      await waitForPromises();

      const expectedVariables = {
        fullPath: 'namespace/project',
        targetBranch: 'feature-branch',
        after: null,
        before: null,
        first: 20,
        last: null,
      };

      expect(activeTrainsHandler).toHaveBeenCalledWith(expectedVariables);
      expect(mergedTrainsHandler).toHaveBeenCalledWith({
        status: 'COMPLETED',
        ...expectedVariables,
      });
    });

    it('refetches query on pageChange event', async () => {
      createComponent();

      await waitForPromises();

      const paginationInfo = {
        first: 20,
        after: 'eyJpZCI6IjUzIn0',
        last: null,
        before: null,
      };

      findActiveTable().vm.$emit('pageChange', paginationInfo);

      await waitForPromises();

      expect(activeTrainsHandler).toHaveBeenCalledWith({
        fullPath: 'namespace/project',
        targetBranch: 'master',
        ...paginationInfo,
      });
    });
  });

  describe('errors', () => {
    it('shows query error for completed merge trains', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, activeTrainsHandler],
        [getCompletedMergeTrainsQuery, errorHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while trying to fetch the completed merge train.',
      });
    });

    it('shows query error for active merge trains', async () => {
      createComponent([
        [getActiveMergeTrainsQuery, errorHandler],
        [getCompletedMergeTrainsQuery, mergedTrainsHandler],
      ]);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while trying to fetch the active merge train.',
      });
    });
  });
});
