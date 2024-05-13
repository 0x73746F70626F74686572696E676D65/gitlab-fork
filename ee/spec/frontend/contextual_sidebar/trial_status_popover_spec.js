import { GlPopover } from '@gitlab/ui';
import { GlBreakpointInstance } from '@gitlab/ui/dist/utils';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import timezoneMock from 'timezone-mock';
import { POPOVER } from 'ee/contextual_sidebar/components/constants';
import TrialStatusPopover from 'ee/contextual_sidebar/components/trial_status_popover.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { __ } from '~/locale';
import { stubExperiments } from 'helpers/experimentation_helper';

Vue.config.ignoredElements = ['gl-emoji'];

describe('TrialStatusPopover component', () => {
  let wrapper;
  let trackingSpy;

  const { trackingEvents } = POPOVER;
  const defaultDaysRemaining = 20;
  const buttonAttributes = {
    size: 'small',
    variant: 'confirm',
    category: 'secondary',
    class: 'gl-w-full',
    buttonTextClasses: 'gl-font-sm',
    href: '#',
    'data-testid': 'trial-popover-hand-raise-lead-button',
  };

  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findLearnAboutFeaturesBtn = () => wrapper.findByTestId('learn-about-features-btn');
  const handRaiseLeadBtn = () => wrapper.findComponent(HandRaiseLeadButton);

  const expectTracking = (category, { action, ...options } = {}) => {
    return expect(trackingSpy).toHaveBeenCalledWith(category, action, { category, ...options });
  };

  const createComponent = ({ providers = {}, mountFn = shallowMount, stubs = {} } = {}) => {
    return extendedWrapper(
      mountFn(TrialStatusPopover, {
        provide: {
          containerId: undefined,
          daysRemaining: defaultDaysRemaining,
          planName: 'Ultimate',
          plansHref: 'billing/path-for/group',
          trialDiscoverPagePath: 'discover-path',
          targetId: 'target-element-identifier',
          trialEndDate: new Date('2021-02-21'),
          ...providers,
        },
        stubs,
      }),
    );
  };

  beforeEach(() => {
    wrapper = createComponent();
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('interpolated strings', () => {
    it('correctly interpolates them all', () => {
      wrapper = createComponent({ providers: undefined, mountFn: mount });

      expect(wrapper.text()).not.toMatch(/%{\w+}/);
    });
  });

  describe('title', () => {
    it('correctly displays when days remaining is 1', () => {
      wrapper = createComponent({ providers: { daysRemaining: 1 }, mountFn: mount });

      expect(wrapper.text()).toContain(__("You've got 1 day remaining on GitLab Ultimate!"));
    });

    it('correct displays when days remaining is 30', () => {
      wrapper = createComponent({ providers: { daysRemaining: 30 }, mountFn: mount });

      expect(wrapper.text()).toContain(__("You've got 30 days remaining on GitLab Ultimate!"));
    });

    it('displays correct message when namespace is not in active trial', () => {
      wrapper = createComponent({ providers: { daysRemaining: -5 }, mountFn: mount });

      expect(wrapper.text()).toContain(POPOVER.i18n.popoverTitleExpiredTrial);
    });
  });

  describe('popover css classes', () => {
    it('does not set width when showing active trial status', () => {
      expect(findGlPopover().props('cssClasses')).toEqual(['gl-p-2']);
    });

    it('sets width when showing expired trial status', () => {
      wrapper = createComponent({ providers: { daysRemaining: -5 }, mountFn: mount });

      expect(findGlPopover().props('cssClasses')).toEqual(['gl-p-2', 'gl-w-28']);
    });
  });

  describe('content', () => {
    it('displays correct message when namespace is in active trial', () => {
      wrapper = createComponent({ providers: { daysRemaining: 5 }, mountFn: mount });

      expect(wrapper.text()).toContain(__('To keep those features after your trial ends'));
    });

    it('displays correct message when namespace is not in active trial', () => {
      wrapper = createComponent({ providers: { daysRemaining: -5 }, mountFn: mount });

      expect(wrapper.text()).toContain(POPOVER.i18n.popoverContentExpiredTrial);
    });
  });

  it('sets correct props to the hand raise lead button', () => {
    expect(handRaiseLeadBtn().props()).toMatchObject({
      buttonAttributes,
      glmContent: 'trial-status-show-group',
    });
  });

  it('tracks when the compare button is clicked', () => {
    wrapper.findByTestId('compare-btn').vm.$emit('click');

    expectTracking(trackingEvents.activeTrialCategory, trackingEvents.compareBtnClick);
  });

  describe('CTA tracking for namespace not in an active trial', () => {
    beforeEach(() => {
      wrapper = createComponent({ providers: { daysRemaining: -5 } });
    });

    it('sets correct props to the hand raise lead button', () => {
      expect(handRaiseLeadBtn().props()).toMatchObject({
        buttonAttributes,
        glmContent: 'trial-status-show-group',
        ctaTracking: {
          category: trackingEvents.trialEndedCategory,
          action: trackingEvents.contactSalesBtnClick.action,
          label: trackingEvents.contactSalesBtnClick.label,
          experiment: 'trial_discover_page',
        },
      });
    });

    it('tracks when the compare button is clicked', () => {
      wrapper.findByTestId('compare-btn').vm.$emit('click');

      expectTracking(trackingEvents.trialEndedCategory, trackingEvents.compareBtnClick);
    });
  });

  it('does not include the word "Trial" if the plan name includes it', () => {
    wrapper = createComponent({ providers: { planName: 'Ultimate Trial' }, mountFn: mount });

    const popoverText = wrapper.text();

    expect(popoverText).toContain('We hope you’re enjoying the features of GitLab Ultimate.');
  });

  describe('correct date in different timezone', () => {
    beforeEach(() => {
      timezoneMock.register('US/Pacific');
    });

    afterEach(() => {
      timezoneMock.unregister();
    });

    it('converts date correctly to UTC', () => {
      wrapper = createComponent({ providers: { planName: 'Ultimate Trial' }, mountFn: mount });

      const popoverText = wrapper.text();

      expect(popoverText).toContain('February 21');
    });
  });

  describe('methods', () => {
    describe('updateDisabledState', () => {
      it.each`
        bp      | isDisabled
        ${'xs'} | ${'true'}
        ${'sm'} | ${'true'}
        ${'md'} | ${undefined}
        ${'lg'} | ${undefined}
        ${'xl'} | ${undefined}
      `(
        'sets disabled to `$isDisabled` when the breakpoint is "$bp"',
        async ({ bp, isDisabled }) => {
          jest.spyOn(GlBreakpointInstance, 'getBreakpointSize').mockReturnValue(bp);

          window.dispatchEvent(new Event('resize'));
          await nextTick();

          expect(findGlPopover().attributes('disabled')).toBe(isDisabled);
        },
      );
    });

    describe('onShown', () => {
      it('dispatches tracking event', () => {
        findGlPopover().vm.$emit('shown');

        expectTracking(trackingEvents.activeTrialCategory, trackingEvents.popoverShown);
      });

      it('dispatches tracking event when namespace is not in an active trial', () => {
        wrapper = createComponent({ providers: { daysRemaining: -5 } });

        findGlPopover().vm.$emit('shown');

        expectTracking(trackingEvents.trialEndedCategory, trackingEvents.popoverShown);
      });
    });
  });

  describe('trial_discover_page experiment', () => {
    describe('when experiment is control', () => {
      beforeEach(() => {
        stubExperiments({ trial_discover_page: 'control' });
      });

      it('does not render link to discover page', () => {
        wrapper = createComponent({ providers: { daysRemaining: 5 }, mountFn: mount });

        expect(wrapper.text()).not.toContain(__('Learn about features'));
        expect(findLearnAboutFeaturesBtn().exists()).toBe(false);
      });
    });

    describe('when experiment is candidate', () => {
      beforeEach(() => {
        stubExperiments({ trial_discover_page: 'candidate' });
      });

      it('renders link to discover page', () => {
        wrapper = createComponent({ providers: { daysRemaining: 5 }, mountFn: mount });

        expect(wrapper.text()).toContain(__('Learn about features'));
        expect(findLearnAboutFeaturesBtn().exists()).toBe(true);
        expect(findLearnAboutFeaturesBtn().attributes('href')).toBe('discover-path');
      });

      it('tracks click event', () => {
        wrapper = createComponent({ providers: { daysRemaining: 5 } });

        findLearnAboutFeaturesBtn().vm.$emit('click');

        expectTracking(trackingEvents.activeTrialCategory, {
          ...trackingEvents.learnAboutFeaturesClick,
          context: {
            data: {
              experiment: 'trial_discover_page',
              variant: 'candidate',
            },
            schema: 'iglu:com.gitlab/gitlab_experiment/jsonschema/1-0-0',
          },
        });
      });
    });
  });
});
