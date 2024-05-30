import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { INSTANCE_TYPE, GROUP_TYPE } from '~/ci/runner/constants';
import RunnerCount from '~/ci/runner/components/stat/runner_count.vue';

import RunnerDashboardStat from 'ee_component/ci/runner/components/runner_dashboard_stat.vue';

describe('RunnerDashboardStat', () => {
  let wrapper;

  const findRunnerCount = () => wrapper.findComponent(RunnerCount);

  const createComponent = ({ props, count, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerDashboardStat, {
      propsData: {
        scope: INSTANCE_TYPE,
        variables: {},
        ...props,
      },
      stubs: {
        RunnerCount: {
          ...stubComponent(RunnerCount),
          render() {
            return this.$scopedSlots.default({ count });
          },
        },
      },
      ...options,
    });
  };

  it('shows title in slot', () => {
    createComponent({
      scopedSlots: {
        title: () => 'My title',
      },
    });

    expect(wrapper.find('h2').text()).toBe('My title');
  });

  it('shows formatted runner count', () => {
    createComponent({
      count: 1000,
    });

    expect(findRunnerCount().text()).toBe('1,000');
  });

  it('filters runner count', () => {
    const mockVariables = { status: 'STATUS_ONLINE' };

    createComponent({
      props: {
        variables: mockVariables,
      },
    });

    expect(findRunnerCount().props()).toMatchObject({
      scope: INSTANCE_TYPE,
      variables: mockVariables,
    });
  });

  it('filters using runner scope', () => {
    createComponent({
      props: {
        scope: GROUP_TYPE,
      },
    });

    expect(findRunnerCount().props('scope')).toBe(GROUP_TYPE);
  });
});
