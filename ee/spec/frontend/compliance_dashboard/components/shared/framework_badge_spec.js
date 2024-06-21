import { GlLabel, GlButton, GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';

import { ROUTE_EDIT_FRAMEWORK } from 'ee/compliance_dashboard/constants';
import { complianceFramework } from '../../mock_data';

describe('FrameworkBadge component', () => {
  let wrapper;
  let routerPushMock;

  const findLabel = () => wrapper.findComponent(GlLabel);
  const findTooltip = () => wrapper.findComponent(GlPopover);
  const findEditButton = () => wrapper.findComponent(GlPopover).findComponent(GlButton);

  const createComponent = (props = {}) => {
    routerPushMock = jest.fn();
    return shallowMount(FrameworkBadge, {
      propsData: {
        ...props,
      },
      mocks: {
        $router: { push: routerPushMock },
      },
    });
  };

  describe('default behavior', () => {
    it('renders edit link', () => {
      wrapper = createComponent({ framework: complianceFramework });

      expect(findEditButton().exists()).toBe(true);
    });

    it('emits edit event when edit link is clicked', async () => {
      wrapper = createComponent({ framework: complianceFramework });

      await findEditButton().vm.$emit('click', new MouseEvent('click'));
      expect(routerPushMock).toHaveBeenCalledWith({
        name: ROUTE_EDIT_FRAMEWORK,
        params: {
          id: complianceFramework.id,
        },
      });
    });

    it('renders the framework label', () => {
      wrapper = createComponent({ framework: complianceFramework });

      expect(findLabel().props()).toMatchObject({
        backgroundColor: '#009966',
        title: complianceFramework.name,
      });
      expect(findTooltip().text()).toContain(complianceFramework.description);
    });

    it('renders the default addition when the framework is default', () => {
      wrapper = createComponent({ framework: { ...complianceFramework, default: true } });

      expect(findLabel().props('title')).toEqual(`${complianceFramework.name} (default)`);
    });

    it('renders the truncated text when the framework name is long', () => {
      wrapper = createComponent({
        framework: {
          ...complianceFramework,
          name: 'A really long standard regulation name that will not fit in one line',
          default: false,
        },
      });

      expect(findLabel().props('title')).toEqual('A really long standard regulat...');
    });

    it('does not render the default addition when the framework is default but component is configured to hide the badge', () => {
      wrapper = createComponent({
        framework: { ...complianceFramework, default: true },
        showDefault: false,
      });

      expect(findLabel().props('title')).toEqual(complianceFramework.name);
    });

    it('does not render the default addition when the framework is not default', () => {
      wrapper = createComponent({ framework: complianceFramework });

      expect(findLabel().props('title')).toEqual(complianceFramework.name);
    });

    it('does not render the popover when showPopover prop is false', () => {
      wrapper = createComponent({ framework: complianceFramework, showPopover: false });

      expect(findTooltip().exists()).toBe(false);
    });

    it('renders closeable label when closeable is true', () => {
      wrapper = createComponent({ framework: complianceFramework, closeable: true });

      expect(findLabel().props('showCloseButton')).toBe(true);
    });
  });
});
