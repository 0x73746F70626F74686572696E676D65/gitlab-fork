import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import GroupRunnersActiveList from 'ee/ci/runner/group_runners_dashboard/group_runners_active_list.vue';
import groupMostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/group_most_active_runners.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { captureException } from '~/ci/runner/sentry_utils';
import { JOBS_ROUTE_PATH } from '~/ci/runner/constants';

import { groupMostActiveRunnersData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/ci/runner/sentry_utils');

const [edge1] = groupMostActiveRunnersData.data.group.runners.edges;

Vue.use(VueApollo);

describe('GroupRunnersActiveList', () => {
  let wrapper;
  let groupMostActiveRunnersHandler;

  const findRunnersActiveList = () => wrapper.findComponent(RunnerActiveList);

  const createComponent = () => {
    wrapper = shallowMountExtended(GroupRunnersActiveList, {
      propsData: {
        groupFullPath: 'group-path',
      },
      apolloProvider: createMockApollo([
        [groupMostActiveRunnersQuery, groupMostActiveRunnersHandler],
      ]),
    });
  };

  beforeEach(() => {
    groupMostActiveRunnersHandler = jest.fn();
  });

  it('Requests most active runners', () => {
    createComponent();

    expect(groupMostActiveRunnersHandler).toHaveBeenCalledTimes(1);
  });

  describe('When loading data', () => {
    it('should show a loading skeleton', () => {
      createComponent();

      expect(findRunnersActiveList().props('loading')).toBe(true);
    });
  });

  describe('When there are active runners', () => {
    beforeEach(async () => {
      groupMostActiveRunnersHandler.mockResolvedValue(groupMostActiveRunnersData);

      createComponent();
      await waitForPromises();
    });

    it('shows results', () => {
      expect(findRunnersActiveList().props('loading')).toBe(false);
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(2);
    });

    it('shows runner jobs url', () => {
      const { webUrl, node } = edge1;

      expect(findRunnersActiveList().props('activeRunners')[0]).toMatchObject(node);
      expect(findRunnersActiveList().props('activeRunners')[0].jobsUrl).toEqual(
        `${webUrl}#${JOBS_ROUTE_PATH}`,
      );
    });
  });

  describe('When there are active runners with no active jobs', () => {
    beforeEach(async () => {
      const resolvedValue = cloneDeep(groupMostActiveRunnersData);
      resolvedValue.data.group.runners.edges[1].node.runningJobCount = 0; // second result should ignored

      groupMostActiveRunnersHandler.mockResolvedValue(resolvedValue);

      createComponent();
      await waitForPromises();
    });

    it('ignores runners with no active jobs', () => {
      expect(findRunnersActiveList().props('activeRunners')).toHaveLength(1);
      expect(findRunnersActiveList().props('activeRunners')[0].id).toBe(edge1.node.id);
    });
  });

  describe('When an error occurs', () => {
    beforeEach(async () => {
      groupMostActiveRunnersHandler.mockRejectedValue(new Error('Error!'));

      createComponent();
      await waitForPromises();
    });

    it('shows an error', () => {
      expect(createAlert).toHaveBeenCalled();
    });

    it('reports an error', () => {
      expect(captureException).toHaveBeenCalledWith({
        component: 'GroupRunnerActiveList',
        error: expect.any(Error),
      });
    });
  });
});
