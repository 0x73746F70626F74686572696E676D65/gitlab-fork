import { GlSkeletonLoading } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import UserPopover from '~/vue_shared/components/user_popover/user_popover.vue';
import Icon from '~/vue_shared/components/icon.vue';

const DEFAULT_PROPS = {
  loaded: true,
  user: {
    username: 'root',
    name: 'Administrator',
    location: 'Vienna',
    bio: null,
    organization: null,
    status: null,
  },
};

describe('User Popover Component', () => {
  const fixtureTemplate = 'merge_requests/diff_comment.html';
  preloadFixtures(fixtureTemplate);

  let wrapper;

  beforeEach(() => {
    loadFixtures(fixtureTemplate);
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('Empty', () => {
    beforeEach(() => {
      wrapper = shallowMount(UserPopover, {
        propsData: {
          target: document.querySelector('.js-user-link'),
          user: {
            name: null,
            username: null,
            location: null,
            bio: null,
            organization: null,
            status: null,
          },
        },
        attachToDocument: true,
        sync: false,
      });
    });

    it('should return skeleton loaders', () => {
      expect(wrapper.find(GlSkeletonLoading).exists()).toBe(true);
    });
  });

  describe('basic data', () => {
    it('should show basic fields', () => {
      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.text()).toContain(DEFAULT_PROPS.user.name);
      expect(wrapper.text()).toContain(DEFAULT_PROPS.user.username);
      expect(wrapper.text()).toContain(DEFAULT_PROPS.user.location);
    });

    it('shows icon for location', () => {
      const iconEl = wrapper.find(Icon);

      expect(iconEl.props('name')).toEqual('location');
    });
  });

  describe('job data', () => {
    it('should show only bio if no organization is available', () => {
      const user = { ...DEFAULT_PROPS.user, bio: 'Engineer' };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.text()).toContain('Engineer');
    });

    it('should show only organization if no bio is available', () => {
      const user = { ...DEFAULT_PROPS.user, organization: 'GitLab' };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.text()).toContain('GitLab');
    });

    it('should display bio and organization in separate lines', () => {
      const user = { ...DEFAULT_PROPS.user, bio: 'Engineer', organization: 'GitLab' };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-bio').text()).toContain('Engineer');
      expect(wrapper.find('.js-organization').text()).toContain('GitLab');
    });

    it('should not encode special characters in bio and organization', () => {
      const user = {
        ...DEFAULT_PROPS.user,
        bio: 'Manager & Team Lead',
        organization: 'Me & my <funky> Company',
      };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-bio').text()).toContain('Manager & Team Lead');
      expect(wrapper.find('.js-organization').text()).toContain('Me & my <funky> Company');
    });

    it('shows icon for bio', () => {
      expect(wrapper.findAll(Icon).filter(icon => icon.props('name') === 'profile').length).toEqual(
        1,
      );
    });

    it('shows icon for organization', () => {
      expect(wrapper.findAll(Icon).filter(icon => icon.props('name') === 'work').length).toEqual(1);
    });
  });

  describe('status data', () => {
    it('should show only message', () => {
      const user = { ...DEFAULT_PROPS.user, status: { message_html: 'Hello World' } };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-user-status').exists()).toBe(true);
      expect(wrapper.text()).toContain('Hello World');
    });

    it('should show message and emoji', () => {
      const user = {
        ...DEFAULT_PROPS.user,
        status: { emoji: 'basketball_player', message_html: 'Hello World' },
      };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-user-status').exists()).toBe(true);
      expect(wrapper.text()).toContain('Hello World');
      expect(wrapper.html()).toContain('<gl-emoji data-name="basketball_player"');
    });

    it('hides the div when status is null', () => {
      const user = { ...DEFAULT_PROPS.user, status: null };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-user-status').exists()).toBe(false);
    });

    it('hides the div when status is empty', () => {
      const user = { ...DEFAULT_PROPS.user, status: { emoji: '', message_html: '' } };

      wrapper = shallowMount(UserPopover, {
        propsData: {
          ...DEFAULT_PROPS,
          user,
          target: document.querySelector('.js-user-link'),
        },
        sync: false,
      });

      expect(wrapper.find('.js-user-status').exists()).toBe(false);
    });
  });
});
