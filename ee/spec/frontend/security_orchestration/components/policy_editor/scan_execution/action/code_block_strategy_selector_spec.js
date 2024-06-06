import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import CodeBlockStrategySelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/code_block_strategy_selector.vue';
import {
  INJECT,
  OVERRIDE,
  CUSTOM_STRATEGY_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('CodeBlockStrategySelector', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(CodeBlockStrategySelector, {
      propsData,
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('selects action type', () => {
    createComponent();
    expect(findListBox().props('selected')).toBe(INJECT);
    findListBox().vm.$emit('select', INJECT);
    expect(wrapper.emitted('select')).toEqual([[INJECT]]);
    findListBox().vm.$emit('select', OVERRIDE);
    expect(wrapper.emitted('select')[1]).toEqual([OVERRIDE]);
  });

  it.each([INJECT, OVERRIDE])('renders strategy', (strategy) => {
    createComponent({
      propsData: {
        strategy,
      },
    });

    expect(findListBox().props('selected')).toBe(strategy);
    expect(findListBox().props('toggleText')).toBe(CUSTOM_STRATEGY_OPTIONS[strategy]);
  });
});
