import { GlLink, GlPopover, GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import RuleName from 'ee/approvals/components/rule_name.vue';

Vue.use(Vuex);

describe('RuleName component', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(RuleName, {
      propsData: {
        ...props,
      },
      provide: {
        vulnerabilityCheckHelpPagePath: '/vuln-check-docs',
        licenseCheckHelpPagePath: '/liceene-check-docs',
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe.each`
    name                     | hasTooltip | hasLink
    ${'Foo'}                 | ${false}   | ${false}
    ${'Vulnerability-Check'} | ${true}    | ${true}
    ${'License-Check'}       | ${true}    | ${true}
  `('with job name set to $name', ({ name, hasTooltip, hasLink }) => {
    beforeEach(() => {
      createWrapper({ name });
    });

    it(`should ${hasTooltip ? '' : 'not'} render the tooltip`, () => {
      expect(wrapper.find(GlPopover).exists()).toBe(hasTooltip);
      expect(wrapper.find(GlIcon).exists()).toBe(hasTooltip);
    });

    it(`should ${hasLink ? '' : 'not'} render the tooltip more info link`, () => {
      expect(wrapper.find(GlLink).exists()).toBe(hasLink);
    });

    it('should render the name', () => {
      expect(wrapper.text()).toContain(name);
    });
  });
});
