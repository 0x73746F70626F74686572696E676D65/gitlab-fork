import { GlPopover, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BreakingChangesIcon from 'ee/security_orchestration/components/policies/breaking_changes_icon.vue';

describe('BreakingChangesIcon', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BreakingChangesIcon, {
      propsData: {
        id: '1',
        ...propsData,
      },
      stubs: {
        GlPopover,
        GlSprintf,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  it('renders warning icon and popover by default', () => {
    createComponent();

    expect(findIcon().props('name')).toBe('warning');
    expect(findIcon().classes()).toEqual(['gl-text-orange-600']);

    expect(findLink().attributes('href')).toBe(
      '/help/user/application_security/policies/scan-result-policies#merge-request-approval-policy-schema',
    );
    expect(findPopover().text()).toBe(
      "You must edit the policy and replace the deprecated syntax. For details on it's replacement, see the policy documentation.",
    );
  });

  it('renders deprecated properties in popover text', () => {
    createComponent({
      propsData: {
        deprecatedProperties: ['test', 'test1'],
      },
    });

    expect(findPopover().text()).toBe(
      "You must edit the policy and replace the deprecated syntax (test, test1). For details on it's replacement, see the policy documentation.",
    );
  });
});
