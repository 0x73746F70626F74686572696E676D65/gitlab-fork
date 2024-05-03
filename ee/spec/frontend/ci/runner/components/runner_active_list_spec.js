import { GlLink, GlTable, GlSkeletonLoader } from '@gitlab/ui';
import { extendedWrapper, mountExtended } from 'helpers/vue_test_utils_helper';

import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { JOBS_ROUTE_PATH } from '~/ci/runner/constants';
import { mostActiveRunnersData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/ci/runner/sentry_utils');

const mostActiveRunners = mostActiveRunnersData.data.runners.nodes;
const [{ adminUrl, ...mockRunner }, { adminUrl2, ...mockRunner2 }] = mostActiveRunners;

mockRunner.jobsUrl = `${adminUrl}#${JOBS_ROUTE_PATH}`;
mockRunner2.jobsUrl = `${adminUrl2}#${JOBS_ROUTE_PATH}`;

// Vue.use(VueApollo);

describe('RunnerActiveList', () => {
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findHeaders = () => wrapper.findAll('thead th');
  const findRows = () => wrapper.findAll('tbody tr');
  const findCell = (row = 0, fieldKey) =>
    extendedWrapper(findRows().at(row).find(`[data-testid="td-${fieldKey}"]`));

  const createComponent = ({ props = {}, ...options } = {}) => {
    wrapper = mountExtended(RunnerActiveList, {
      propsData: {
        ...props,
      },
      ...options,
    });
  };

  describe('When loading data', () => {
    it('should show a loading skeleton', () => {
      createComponent({ props: { loading: true }, mountFn: mountExtended });

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('When there are active runners', () => {
    beforeEach(() => {
      createComponent({
        props: {
          activeRunners: [mockRunner, mockRunner2],
        },
        mountFn: mountExtended,
      });
    });

    it('shows table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('shows headers', () => {
      const headers = findHeaders().wrappers.map((w) => w.text());
      expect(headers).toEqual(['', 'Runner', 'Running Jobs']);
    });

    it('shows runners', () => {
      expect(findRows()).toHaveLength(mostActiveRunners.length);

      // Row 1
      const runner = `#${getIdFromGraphQLId(mockRunner.id)} (${mockRunner.shortSha}) - ${
        mockRunner.description
      }`;
      expect(findCell(0, 'index').text()).toBe('1');
      expect(findCell(0, 'runner').text()).toBe(runner);
      expect(findCell(0, 'runningJobCount').text()).toBe('2');

      // Row 2
      const runner2 = `#${getIdFromGraphQLId(mockRunner2.id)} (${mockRunner2.shortSha}) - ${
        mockRunner2.description
      }`;
      expect(findCell(1, 'index').text()).toBe('2');
      expect(findCell(1, 'runner').text()).toBe(runner2);
      expect(findCell(1, 'runningJobCount').text()).toBe('1');
    });

    it('shows jobs link', () => {
      const url = findCell(0, 'runningJobCount').findComponent(GlLink).attributes('href');
      expect(url).toBe(mockRunner.jobsUrl);
    });
  });

  describe('When there are no runners', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('should render no runners', () => {
      expect(findTable().exists()).toBe(false);

      expect(wrapper.text()).toContain('no runners');
    });
  });
});
