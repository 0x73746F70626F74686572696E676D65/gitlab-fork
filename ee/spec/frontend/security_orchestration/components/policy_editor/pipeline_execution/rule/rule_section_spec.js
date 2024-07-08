import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';

describe('RuleSection', () => {
  let wrapper;

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(RuleSection, {
      propsData: {
        ...propsData,
      },
      provide: {
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findGlLink = () => wrapper.findComponent(GlLink);

  it('renders text', () => {
    factory();
    expect(findGlSprintf().text()).toBe(
      'Configure your conditions in the pipeline execution file.',
    );
  });

  it('renders link', () => {
    factory();
    expect(findGlLink().exists()).toBe(true);
    expect(findGlLink().text()).toBe('What can pipeline execution do?');
    expect(findGlLink().attributes('href')).toBe(
      '/help/user/application_security/policies/pipeline_execution_policies',
    );
  });
});
