import { GlIcon } from '@gitlab/ui';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { INSTANCE_TYPE, GROUP_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';
import RunnerDashboardStat from 'ee/ci/runner/components/runner_dashboard_stat.vue';

import RunnerDashboardStatStatus from 'ee/ci/runner/components/runner_dashboard_stat_status.vue';

describe('RunnerDashboardStatStatus', () => {
  let wrapper;

  const findRunnerDashboardStat = () => wrapper.findComponent(RunnerDashboardStat);
  const findIcon = () => wrapper.findComponent(GlIcon);

  const createComponent = ({ props, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerDashboardStatStatus, {
      propsData: {
        ...props,
      },
      stubs: {
        RunnerDashboardStat: stubComponent(RunnerDashboardStat, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
      ...options,
    });
  };

  beforeEach(() => {});

  describe.each`
    scope            | status            | title        | icon
    ${INSTANCE_TYPE} | ${STATUS_ONLINE}  | ${'Online'}  | ${'status-active'}
    ${INSTANCE_TYPE} | ${STATUS_OFFLINE} | ${'Offline'} | ${'status-waiting'}
    ${GROUP_TYPE}    | ${STATUS_ONLINE}  | ${'Online'}  | ${'status-active'}
    ${GROUP_TYPE}    | ${STATUS_OFFLINE} | ${'Offline'} | ${'status-waiting'}
  `('for runner of scope $scope and runner status $status', ({ scope, status, title, icon }) => {
    beforeEach(() => {
      createComponent({
        props: { scope, status },
      });
    });

    it(`shows title "${title}"`, () => {
      expect(wrapper.text()).toBe(title);
    });

    it(`shows icon "${icon}"`, () => {
      expect(findIcon().props()).toMatchObject({
        name: icon,
        size: 12,
      });
    });

    it(`shows ${title} runners`, () => {
      expect(findRunnerDashboardStat().props()).toEqual({
        scope,
        variables: { status },
      });
    });

    it(`filters ${title} runners with additional variables`, () => {
      createComponent({
        props: { scope, status, variables: { key: 'value' } },
      });

      expect(findRunnerDashboardStat().props()).toEqual({
        scope,
        variables: { key: 'value', status },
      });
    });
  });
});
