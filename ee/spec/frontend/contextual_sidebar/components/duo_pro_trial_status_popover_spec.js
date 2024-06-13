import { GlPopover } from '@gitlab/ui';
import { GlBreakpointInstance } from '@gitlab/ui/dist/utils';
import { nextTick } from 'vue';
import timezoneMock from 'timezone-mock';
import { DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY } from 'ee/contextual_sidebar/components/constants';
import DuoProTrialStatusPopover from 'ee/contextual_sidebar/components/duo_pro_trial_status_popover.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

describe('DuoProTrialStatusPopover component', () => {
  let wrapper;
  let trackingSpy;

  const defaultDaysRemaining = 20;

  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findPurchaseNowBtn = () => wrapper.findByTestId('purchase-now-btn');
  const findLearnAboutFeaturesBtn = () => wrapper.findByTestId('learn-about-features-btn');
  const handRaiseLeadBtn = () => wrapper.findComponent(HandRaiseLeadButton);

  const expectTracking = ({ action, ...options } = {}) => {
    return expect(trackingSpy).toHaveBeenCalledWith(
      DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
      action,
      { category: DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY, ...options },
    );
  };

  const createComponent = ({ providers = {}, mountFn = shallowMountExtended, stubs = {} } = {}) => {
    wrapper = mountFn(DuoProTrialStatusPopover, {
      provide: {
        containerId: undefined,
        daysRemaining: defaultDaysRemaining,
        planName: 'Ultimate',
        purchaseNowUrl: 'usage_quota/path-for/group',
        targetId: 'target-element-identifier',
        trialEndDate: new Date('2021-02-21'),
        learnAboutButtonUrl: 'add_ons/discover_duo_pro',
        ...providers,
      },
      stubs,
    });
  };

  beforeEach(() => {
    createComponent();
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('title', () => {
    it('correctly displays when days remaining is 1', () => {
      createComponent({ providers: { daysRemaining: 1 }, mountFn: mountExtended });

      expect(
        wrapper.findByText("You've got 1 day remaining on your GitLab Duo Pro trial!").exists(),
      ).toBe(true);
    });

    it('correct displays when days remaining is 60', () => {
      createComponent({ providers: { daysRemaining: 60 }, mountFn: mountExtended });

      expect(
        wrapper.findByText("You've got 60 days remaining on your GitLab Duo Pro trial!").exists(),
      ).toBe(true);
    });
  });

  describe('popover css classes', () => {
    it('does not set width when showing active trial status', () => {
      expect(findGlPopover().props('cssClasses')).toEqual(['gl-p-2']);
    });
  });

  describe('content', () => {
    it('displays correct message when namespace is in active trial', () => {
      createComponent({ providers: { daysRemaining: 5 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain('To continue using your AI-powered assistant');
    });
  });

  describe('buttons', () => {
    it('sets correct props to the hand raise lead button', () => {
      const buttonAttributes = {
        size: 'small',
        variant: 'confirm',
        category: 'secondary',
        class: 'gl-w-full',
        buttonTextClasses: 'gl-text-sm',
        href: '#',
        'data-testid': 'duo-pro-trial-popover-hand-raise-lead-button',
      };

      expect(handRaiseLeadBtn().props()).toMatchObject({
        buttonAttributes,
        glmContent: 'duo-pro-trial-status-show-group',
        ctaTracking: {
          category: DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
          action: 'click_button',
          label: 'contact_sales',
        },
      });
    });

    it('sets correct attributes to the learn more about features button', () => {
      expect(findLearnAboutFeaturesBtn().attributes('href')).toBe('add_ons/discover_duo_pro');
      expect(findLearnAboutFeaturesBtn().attributes('target')).toBe(undefined);
    });

    it('tracks when the purchase now button is clicked', () => {
      const options = {
        action: 'click_button',
        label: 'purchase_now',
      };

      findPurchaseNowBtn().vm.$emit('click');

      expectTracking(options);
    });

    it('tracks when the learn about button is clicked', () => {
      const options = {
        action: 'click_button',
        label: 'learn_about_features',
      };

      findLearnAboutFeaturesBtn().vm.$emit('click');

      expectTracking(options);
    });
  });

  describe('correct date in different timezone', () => {
    beforeEach(() => {
      timezoneMock.register('US/Pacific');
    });

    afterEach(() => {
      timezoneMock.unregister();
    });

    it('converts date correctly to UTC', () => {
      createComponent({ mountFn: mountExtended });

      expect(wrapper.findByText('February 21').exists()).toBe(true);
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
        const options = {
          action: 'render_popover',
        };

        findGlPopover().vm.$emit('shown');

        expectTracking(options);
      });
    });
  });
});
