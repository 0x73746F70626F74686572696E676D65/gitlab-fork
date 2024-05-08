import { GlButton } from '@gitlab/ui';

import GroupRunnersDashboardApp from 'ee/ci/runner/group_runners_dashboard/group_runners_dashboard_app.vue';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import GroupRunnersActiveList from 'ee/ci/runner/group_runners_dashboard/group_runners_active_list.vue';

const mockGroupPath = 'group';
const mockGroupRunnersPath = '/group/-/runners';
const mockNewRunnerPath = '/runners/new';

describe('GroupRunnersDashboardApp', () => {
  let wrapper;

  const createComponent = (options) => {
    wrapper = shallowMountExtended(GroupRunnersDashboardApp, {
      propsData: {
        groupFullPath: mockGroupPath,
        groupRunnersPath: mockGroupRunnersPath,
        newRunnerPath: mockNewRunnerPath,
      },
      ...options,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows title and actions', () => {
    const [listBtn, newBtn] = wrapper.findAllComponents(GlButton).wrappers;

    expect(listBtn.text()).toBe('View runners list');
    expect(listBtn.attributes('href')).toBe(mockGroupRunnersPath);

    expect(newBtn.text()).toBe('New group runner');
    expect(newBtn.attributes('href')).toBe(mockNewRunnerPath);
  });

  it('shows dashboard panels', () => {
    expect(wrapper.findComponent(GroupRunnersActiveList).props()).toEqual({
      groupFullPath: mockGroupPath,
    });
  });
});
