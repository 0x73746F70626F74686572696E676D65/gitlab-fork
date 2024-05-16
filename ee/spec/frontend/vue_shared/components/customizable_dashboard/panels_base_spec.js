import { nextTick } from 'vue';
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLoadingIcon,
  GlPopover,
  GlIcon,
} from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import PanelsBase from 'ee/vue_shared/components/customizable_dashboard/panels_base.vue';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import { PANEL_POPOVER_DELAY } from 'ee/vue_shared/components/customizable_dashboard/constants';

describe('PanelsBase', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createWrapper = ({ props = {}, slots = {}, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(PanelsBase, {
      propsData: {
        ...props,
      },
      slots,
    });
  };

  const findPanelTitle = () => wrapper.findComponent(TooltipOnTruncate);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findLoadingDelayedIndicator = () => wrapper.findByTestId('panel-loading-delayed-indicator');
  const findPanelTitleTooltipIcon = () => wrapper.findByTestId('panel-title-tooltip-icon');
  const findPanelTitleErrorIcon = () => wrapper.findByTestId('panel-title-error-icon');
  const findPanelTitlePopover = () => wrapper.findByTestId('panel-title-popover');
  const findPanelErrorPopover = () => wrapper.findComponent(GlPopover);
  const findPanelActionsDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItemByText = (text) =>
    findPanelActionsDropdown()
      .findAllComponents(GlDisclosureDropdownItem)
      .filter((w) => w.text() === text)
      .at(0);

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not render a title', () => {
      expect(findPanelTitle().exists()).toBe(false);
    });

    it('does not render a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findLoadingDelayedIndicator().exists()).toBe(false);
    });

    it('does not render a disclosure dropdown', () => {
      expect(findPanelActionsDropdown().exists()).toBe(false);
    });

    it('does not render an error popover', () => {
      expect(findPanelErrorPopover().exists()).toBe(false);
    });

    it('does not render the tooltip icon', () => {
      expect(findPanelTitleTooltipIcon().exists()).toBe(false);
    });
  });

  describe('with a body slot', () => {
    beforeEach(() => {
      createWrapper({
        slots: {
          body: '<div data-testid="panel-body-slot"></div>',
        },
      });
    });

    it('renders the panel body', () => {
      expect(wrapper.findByTestId('panel-body-slot').exists()).toBe(true);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          loading: true,
        },
      });
    });

    it('renders a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLoadingDelayedIndicator().exists()).toBe(false);
    });

    it('renders the additional "Still loading" indicator if the data source is slow', async () => {
      await wrapper.setProps({ loadingDelayed: true });
      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLoadingDelayedIndicator().exists()).toBe(true);
    });
  });

  describe('when loading with a body slot', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          loading: true,
        },
        slots: {
          body: '<div data-testid="panel-body-slot"></div>',
        },
      });
    });

    it('does not render the panel body', () => {
      expect(wrapper.findByTestId('panel-body-slot').exists()).toBe(false);
    });
  });

  describe('when there is a title', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          title: 'Panel Title',
        },
      });
    });

    it('renders the panel title', () => {
      expect(findPanelTitle().text()).toBe('Panel Title');
    });
  });

  describe('when there is a title with a tooltip', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          title: 'Panel Title',
          tooltip: 'Tooltip text',
        },
      });
    });

    it('renders the panel title tooltip icon', () => {
      expect(findPanelTitleTooltipIcon().exists()).toBe(true);
      expect(findPanelTitlePopover().text()).toContain('Tooltip text');
    });
  });

  describe('when there is a title with an error state', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          title: 'Panel Title',
          showErrorState: true,
        },
      });
    });

    it('renders the panel title error icon', () => {
      expect(findPanelTitleErrorIcon().exists()).toBe(true);
    });
  });

  describe('when editing and there are actions', () => {
    const actions = [
      {
        icon: 'pencil',
        text: 'Edit',
        action: () => {},
      },
    ];

    beforeEach(() => {
      createWrapper({
        props: {
          editing: true,
          actions,
        },
        mountFn: mountExtended,
      });
    });

    it('renders the panel actions dropdown', () => {
      expect(findPanelActionsDropdown().props('items')).toStrictEqual(actions);
    });

    it('renders the panel action dropdown item and icon', () => {
      const dropdownItem = findDropdownItemByText(actions[0].text);

      expect(dropdownItem.exists()).toBe(true);
      expect(dropdownItem.findComponent(GlIcon).props('name')).toBe(actions[0].icon);
    });
  });

  describe('when there is a error title and the error state is true', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          errorPopoverTitle: 'Some error',
          showErrorState: true,
        },
        slots: {
          'error-popover': '<div data-testid="error-popover-slot"></div>',
        },
      });
    });

    it('renders the error popover', () => {
      const popover = findPanelErrorPopover();
      expect(popover.exists()).toBe(true);
      expect(popover.props('title')).toBe('Some error');

      // TODO: Replace with .props() once GitLab-UI adds all supported props.
      // https://gitlab.com/gitlab-org/gitlab-ui/-/issues/428
      expect(popover.vm.$attrs.delay).toStrictEqual(PANEL_POPOVER_DELAY);
    });

    it('renders the error popover slot', () => {
      expect(wrapper.findByTestId('error-popover-slot').exists()).toBe(true);
    });
  });

  describe('when the editing and error state are true', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          showErrorState: true,
          editing: true,
        },
      });
    });

    it('hides the error popover when the dropdown is shown', async () => {
      expect(findPanelErrorPopover().exists()).toBe(true);

      await findPanelActionsDropdown().vm.$emit('shown');

      expect(findPanelErrorPopover().exists()).toBe(false);
    });
  });
});
