import { shallowMount } from '@vue/test-utils';
import { GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { OPEN } from 'ee/security_orchestration/components/policy_editor/scan_result/constants';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/fallback_section.vue';
import DimDisableContainer from 'ee/security_orchestration/components/policy_editor/dim_disable_container.vue';

describe('FallbackSection', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(FallbackSection, {
      propsData: { property: OPEN, ...propsData },
      stubs: { DimDisableContainer },
    });
  };

  const findDimContainer = () => wrapper.findComponent(DimDisableContainer);
  const findAllRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  it('enables the container by default', () => {
    createComponent();
    expect(findDimContainer().props('disabled')).toBe(false);
  });

  it('disables the selection when "disabled" is "true"', () => {
    createComponent({ disabled: true });
    expect(findDimContainer().props('disabled')).toBe(true);
  });

  it('renders the radio buttons', () => {
    createComponent();
    expect(findAllRadioButtons()).toHaveLength(2);
    expect(findAllRadioButtons().at(0).text()).toBe('Fail open');
    expect(findAllRadioButtons().at(1).text()).toBe('Fail closed');
  });

  it('emits when a radio button is clicked', () => {
    createComponent();
    findRadioGroup().vm.$emit('change', OPEN);
    expect(wrapper.emitted('changed')).toEqual([['fallback_behavior', { fail: OPEN }]]);
  });
});
