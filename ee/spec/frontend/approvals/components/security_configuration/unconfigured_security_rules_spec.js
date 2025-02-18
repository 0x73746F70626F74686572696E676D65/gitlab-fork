import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import UnconfiguredSecurityRule from 'ee/approvals/components/security_configuration/unconfigured_security_rule.vue';
import UnconfiguredSecurityRules from 'ee/approvals/components/security_configuration/unconfigured_security_rules.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';

Vue.use(Vuex);

describe('UnconfiguredSecurityRules component', () => {
  let wrapper;
  let store;

  const TEST_PROJECT_ID = '7';

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(UnconfiguredSecurityRules, {
      store: new Vuex.Store(store),
      propsData: {
        ...props,
      },
      provide: {
        glFeatures: {
          editBranchRules: true,
        },
      },
    });
  };

  beforeEach(() => {
    store = createStoreOptions(
      { approvals: projectSettingsModule() },
      { projectId: TEST_PROJECT_ID },
    );

    store.modules.approvals.actions = { openCreateDrawer: jest.fn() };
    jest.spyOn(store.modules.approvals.actions, 'openCreateDrawer');
  });

  describe('when created', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render a unconfigured-security-rule component for every security rule', () => {
      expect(wrapper.findAllComponents(UnconfiguredSecurityRule).length).toBe(1);
    });
  });

  describe.each`
    approvalsLoading | shouldRender
    ${false}         | ${false}
    ${true}          | ${true}
  `('while approvalsLoading is $approvalsLoading', ({ approvalsLoading, shouldRender }) => {
    beforeEach(() => {
      createWrapper();
      store.state.approvals.isLoading = approvalsLoading;
    });

    it(`should ${shouldRender ? '' : 'not'} render the loading skeleton`, () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(shouldRender);
    });
  });

  it('opens the drawer when a rule is Enabled', () => {
    createWrapper();
    wrapper.findComponent(UnconfiguredSecurityRule).vm.$emit('enable');

    expect(store.modules.approvals.actions.openCreateDrawer).toHaveBeenCalled();
  });
});
