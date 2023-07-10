import { GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CiIcon from '~/vue_shared/components/ci_icon.vue';

describe('CI Icon component', () => {
  let wrapper;

  const createComponent = (props) => {
    wrapper = shallowMount(CiIcon, {
      propsData: {
        ...props,
      },
    });
  };

  it('should render a span element with an svg', () => {
    createComponent({
      status: {
        group: 'success',
        icon: 'status_success',
      },
    });

    expect(wrapper.find('span').exists()).toBe(true);
    expect(wrapper.findComponent(GlIcon).exists()).toBe(true);
  });

  describe.each`
    isActive
    ${true}
    ${false}
  `('when isActive is $isActive', ({ isActive }) => {
    it(`"active" class is ${isActive ? 'not ' : ''}added`, () => {
      wrapper = shallowMount(CiIcon, {
        propsData: {
          status: {
            group: 'success',
            icon: 'status_success',
          },
          isActive,
        },
      });

      expect(wrapper.classes('active')).toBe(isActive);
    });
  });

  describe.each`
    isInteractive
    ${true}
    ${false}
  `('when isInteractive is $isInteractive', ({ isInteractive }) => {
    it(`"interactive" class is ${isInteractive ? 'not ' : ''}added`, () => {
      wrapper = shallowMount(CiIcon, {
        propsData: {
          status: {
            group: 'success',
            icon: 'status_success',
          },
          isInteractive,
        },
      });

      expect(wrapper.classes('interactive')).toBe(isInteractive);
    });
  });

  describe('rendering a status', () => {
    it.each`
      icon                 | group         | cssClass
      ${'status_success'}  | ${'success'}  | ${'ci-status-icon-success'}
      ${'status_failed'}   | ${'failed'}   | ${'ci-status-icon-failed'}
      ${'status_warning'}  | ${'warning'}  | ${'ci-status-icon-warning'}
      ${'status_pending'}  | ${'pending'}  | ${'ci-status-icon-pending'}
      ${'status_running'}  | ${'running'}  | ${'ci-status-icon-running'}
      ${'status_created'}  | ${'created'}  | ${'ci-status-icon-created'}
      ${'status_skipped'}  | ${'skipped'}  | ${'ci-status-icon-skipped'}
      ${'status_canceled'} | ${'canceled'} | ${'ci-status-icon-canceled'}
      ${'status_manual'}   | ${'manual'}   | ${'ci-status-icon-manual'}
    `('should render a $group status', ({ icon, group, cssClass }) => {
      wrapper = shallowMount(CiIcon, {
        propsData: {
          status: {
            icon,
            group,
          },
        },
      });

      expect(wrapper.classes()).toContain(cssClass);
    });
  });
});
