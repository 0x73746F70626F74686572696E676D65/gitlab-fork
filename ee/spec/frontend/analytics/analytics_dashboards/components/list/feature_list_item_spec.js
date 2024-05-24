import { GlIcon, GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import FeatureListItem from 'ee/analytics/analytics_dashboards/components/list/feature_list_item.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { __ } from '~/locale';

describe('FeatureListItem', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgePopover = () => wrapper.findComponent(GlPopover);
  const findButton = () => wrapper.findComponent(GlButton);
  const findButtonLink = () => findButton().find('a');

  const defaultProps = {
    title: 'Hello world',
    description: 'Some description',
    to: 'some-path',
  };

  const createWrapper = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(FeatureListItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the feature title', () => {
      expect(wrapper.text()).toContain(defaultProps.title);
    });

    it('renders the dashboard description', () => {
      expect(wrapper.text()).toContain(defaultProps.description);
    });

    it('renders the setup icon', () => {
      expect(findIcon().props()).toMatchObject({
        name: 'cloud-gear',
        size: 16,
      });
    });

    it('renders the button with default text', () => {
      expect(findButton().text()).toBe(__('Set up'));
    });
  });

  describe('button path', () => {
    beforeEach(() => {
      createWrapper({ to: 'foo-bar' }, mountExtended);
    });

    it('renders the button link', () => {
      expect(findButtonLink().attributes('to')).toBe('foo-bar');
    });
  });

  describe('badge text', () => {
    beforeEach(() => {
      createWrapper({ badgeText: 'waiting' });
    });

    it('renders a badge with the badge text', () => {
      expect(findBadge().text()).toBe('waiting');
    });
  });

  describe('badge popover', () => {
    beforeEach(() => {
      createWrapper({ badgeText: 'waiting', badgePopoverText: 'waiting for the foo to bar.' });
    });

    it('renders a popover with the expected text', () => {
      const popover = findBadgePopover();

      expect(popover.text()).toBe('waiting for the foo to bar.');
      expect(popover.props('target')).toBe(findBadge().attributes('id'));
    });
  });

  describe('action text', () => {
    beforeEach(() => {
      createWrapper({ actionText: 'do something' });
    });

    it('renders button with the expected text', () => {
      expect(findButton().text()).toBe('do something');
    });
  });
});
