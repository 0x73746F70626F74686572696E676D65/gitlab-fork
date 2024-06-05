import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAvatar, GlButton } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { INSTANCE_TYPE } from '~/ci/runner/constants';

import RunnerUsageQuery from 'ee/ci/runner/graphql/performance/runner_usage.query.graphql';
import RunnerUsageByProjectQuery from 'ee/ci/runner/graphql/performance/runner_usage_by_project.query.graphql';
import RunnerUsageExportMutation from 'ee/ci/runner/graphql/performance/runner_usage_export.mutation.graphql';

import RunnerUsage from 'ee/ci/runner/components/runner_usage.vue';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('~/sentry/sentry_browser_wrapper');

const mockRunnerUsage = [
  {
    runner: {
      id: 'gid://gitlab/Ci::Runner/1',
      shortSha: 'sha1',
      description: 'Runner 1',
      adminUrl: '/admin/runners/1',
      __typename: 'CiRunner',
    },
    ciMinutesUsed: '111222333444555666777888999', // tests support for BigInt parsing
    __typename: 'CiRunnerUsage',
  },
  {
    runner: {
      id: 'gid://gitlab/Ci::Runner/2',
      shortSha: 'sha2',
      description: 'Runner 2',
      adminUrl: '/admin/runners/2',
      __typename: 'CiRunner',
    },
    ciMinutesUsed: 2001,
    __typename: 'CiRunnerUsage',
  },
  {
    runner: null,
    ciMinutesUsed: 2000,
    __typename: 'CiRunnerUsage',
  },
];

const mockRunnerUsageByProject = [
  {
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Project1',
      nameWithNamespace: 'Group1 / Project1',
      avatarUrl: '/project1.png',
      webUrl: '/group1/project1',
      __typename: 'Project',
    },
    ciMinutesUsed: 1002,
    __typename: 'CiRunnerUsageByProject',
  },
  {
    project: {
      id: 'gid://gitlab/Project/22',
      name: 'Project2',
      nameWithNamespace: 'Group1 / Project2',
      avatarUrl: '/project2.png',
      webUrl: '/group1/project2',
      __typename: 'Project',
    },
    ciMinutesUsed: 1001,
    __typename: 'CiRunnerUsageByProject',
  },
  {
    project: null,
    ciMinutesUsed: 1000,
    __typename: 'CiRunnerUsageByProject',
  },
];

describe('RunnerUsage', () => {
  let wrapper;
  let mockToast;

  let runnerUsageHandler;
  let runnerUsageByProjectHandler;
  let runnerUsageExportHandler;

  const findButton = () => wrapper.findComponent(GlButton);
  const findTopRunners = () => wrapper.findByTestId('top-runners-table').findAll('tr');
  const findTopProjects = () => wrapper.findByTestId('top-projects-table').findAll('tr');

  const clickButton = async () => {
    findButton().vm.$emit('click');
    await waitForPromises();
  };

  const createWrapper = ({ mountFn = shallowMountExtended } = {}) => {
    confirmAction.mockResolvedValue(true);

    mockToast = jest.fn();

    wrapper = mountFn(RunnerUsage, {
      apolloProvider: createMockApollo([
        [RunnerUsageQuery, runnerUsageHandler],
        [RunnerUsageByProjectQuery, runnerUsageByProjectHandler],
        [RunnerUsageExportMutation, runnerUsageExportHandler],
      ]),
      mocks: {
        $toast: { show: mockToast },
      },
    });
  };

  beforeEach(() => {
    runnerUsageHandler = jest.fn().mockResolvedValue({
      data: { runnerUsage: mockRunnerUsage },
    });
    runnerUsageByProjectHandler = jest.fn().mockResolvedValue({
      data: { runnerUsageByProject: mockRunnerUsageByProject },
    });
    runnerUsageExportHandler = jest.fn();
  });

  it('renders button', () => {
    createWrapper();

    expect(findButton().text()).toBe('Export as CSV');
  });

  it('loads top projects', async () => {
    createWrapper({ mountFn: mountExtended });
    await waitForPromises();

    expect(findTopRunners().length).toBe(4);

    const [header, row1, row2, row3] = findTopProjects().wrappers;

    expect(header.text()).toContain('Top projects consuming runners');
    expect(header.text()).toContain('Usage (min)');

    expect(row1.findComponent(GlAvatar).attributes()).toMatchObject({
      label: 'Project1',
      src: '/project1.png',
    });
    expect(row1.text()).toContain('Project1');
    expect(row1.text()).toContain('1,002');

    expect(row2.findComponent(GlAvatar).attributes()).toMatchObject({
      label: 'Project2',
      src: '/project2.png',
    });
    expect(row2.text()).toContain('Project2');
    expect(row2.text()).toContain('1,001');

    expect(row3.text()).toContain('Other projects');
    expect(row3.text()).toContain('1,000');
  });

  it('loads top runners', async () => {
    createWrapper({ mountFn: mountExtended });
    await waitForPromises();

    expect(findTopRunners().length).toBe(4);

    const [header, row1, row2, row3] = findTopRunners().wrappers.map((w) => w.text());

    expect(header).toContain('Most used instance runners');
    expect(header).toContain('Usage (min)');

    expect(row1).toContain('#1 (sha1) - Runner 1');
    expect(row1).toContain('111,222,333,444,555,666,777,888,999');

    expect(row2).toContain('#2 (sha2) - Runner 2');
    expect(row2).toContain('2,001');

    expect(row3).toContain('Other runners');
    expect(row3).toContain('2,000');
  });

  it('shows empty results', async () => {
    runnerUsageHandler.mockResolvedValue({
      data: {
        runnerUsage: [{ runner: null, ciMinutesUsed: null, __typename: 'CiRunnerUsage' }],
      },
    });
    runnerUsageByProjectHandler.mockResolvedValue({
      data: {
        runnerUsageByProject: [
          { project: null, ciMinutesUsed: null, __typename: 'CiRunnerUsageByProject' },
        ],
      },
    });

    createWrapper({ mountFn: mountExtended });
    await waitForPromises();

    const [, projectRow] = findTopProjects().wrappers.map((w) => w.text());
    expect(projectRow).toBe('Other projects -');

    const [, runnerRow] = findTopRunners().wrappers.map((w) => w.text());
    expect(runnerRow).toBe('Other runners -');
  });

  it('calls mutation on button click', async () => {
    createWrapper();

    runnerUsageExportHandler.mockReturnValue(new Promise(() => {}));

    await clickButton();

    expect(runnerUsageExportHandler).toHaveBeenCalledWith({
      input: { runnerType: INSTANCE_TYPE },
    });
    expect(findButton().props('loading')).toBe(true);
  });

  describe('when user does not confirm', () => {
    beforeEach(() => {
      createWrapper();
      confirmAction.mockReturnValue(false);
    });

    it('does not call mutation', async () => {
      await clickButton();

      expect(runnerUsageExportHandler).not.toHaveBeenCalled();
      expect(findButton().props('loading')).toBe(false);
    });
  });

  it('handles successful result', async () => {
    createWrapper();

    runnerUsageExportHandler.mockResolvedValue({
      data: { runnersExportUsage: { errors: [] } },
    });

    await clickButton();

    expect(findButton().props('loading')).toBe(false);
    expect(mockToast).toHaveBeenCalledWith(expect.stringContaining('CSV export has started'));
  });

  describe('when an error occurs', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('handles network error', async () => {
      runnerUsageExportHandler.mockRejectedValue(new Error('Network error'));

      await clickButton();

      expect(findButton().props('loading')).toBe(false);
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining('Something went wrong'),
      });

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Network error'));
    });

    it('handles graphql error', async () => {
      runnerUsageExportHandler.mockResolvedValue({
        data: { runnersExportUsage: { errors: ['Error 1', 'Error 2'] } },
      });

      await clickButton();

      expect(findButton().props('loading')).toBe(false);
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining('Something went wrong'),
      });

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Error 1 Error 2'));
    });
  });
});
