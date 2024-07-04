import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlIntersectionObserver, GlSprintf } from '@gitlab/ui';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { mockTracking } from 'helpers/tracking_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mockHandRaiseLeadData } from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import { VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD } from 'ee/usage_quotas/code_suggestions/constants';

describe('Code Suggestions Intro', () => {
  let wrapper;
  const emptyState = () => wrapper.findComponent(GlEmptyState);
  const handRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);
  const learnMoreLink = () => wrapper.find('[data-testid="duo-pro-learn-more-link"]');
  const trialBtn = () => wrapper.find('[data-testid="duo-pro-start-trial-btn"]');
  const purchaseSeatsBtn = () => wrapper.find('[data-testid="duo-pro-purchase-seats-btn"]');

  const createComponent = (provideProps = {}) => {
    wrapper = shallowMount(CodeSuggestionsIntro, {
      mocks: { GlEmptyState },
      stubs: { GlSprintf },
      provide: {
        ...provideProps,
        handRaiseLeadData: mockHandRaiseLeadData,
      },
    });
  };

  describe('on page load', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD event', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        VIEW_ADMIN_CODE_SUGGESTIONS_PAGELOAD,
        {},
        undefined,
      );
    });
  });

  describe('when rendering', () => {
    it('renders gl-empty-state component with hand raise lead', () => {
      createComponent();

      const buttonProps = {
        ...mockHandRaiseLeadData,
        buttonText: 'Contact sales',
      };

      expect(emptyState().exists()).toBe(true);
      expect(handRaiseLeadButton().exists()).toBe(true);
      expect(handRaiseLeadButton().props()).toEqual(buttonProps);
    });
  });

  describe('with CTA buttons', () => {
    it('renders trial button as primary button when duo pro trial href is present', () => {
      createComponent({ duoProTrialHref: 'some-path' });

      expect(trialBtn().attributes('category')).toEqual('primary');
      expect(purchaseSeatsBtn().attributes('category')).toEqual('secondary');
    });

    it('does not render trial button, render purchase seats button as primary button when duo pro trial href is missing', () => {
      createComponent();

      expect(trialBtn().exists()).toBe(false);
      expect(purchaseSeatsBtn().attributes('category')).toEqual('primary');
    });
  });

  describe('with tracking', () => {
    let trackingSpy;
    const glIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    beforeEach(() => {
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent({ duoProTrialHref: 'some-path' });
    });

    describe('with duo pro tab page view tracking', () => {
      it('tracks when duo pro trial href is present', () => {
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_pro_add_on_tab_pre_trial',
        });
      });

      it('does not track when duo pro trial href is missing', () => {
        createComponent();
        glIntersectionObserver().vm.$emit('appear');
        expect(trackingSpy).not.toHaveBeenCalledWith(undefined, 'pageview', {
          label: 'duo_pro_add_on_tab_pre_trial',
        });
      });
    });

    it('tracks when duo pro learn more link is clicked', () => {
      learnMoreLink().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_link', {
        label: 'duo_pro_marketing_page',
      });
    });

    it('tracks when duo pro start trial button is clicked', () => {
      trialBtn().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'duo_pro_start_trial',
      });
    });

    it('tracks when duo pro purchase seats button is clicked', () => {
      purchaseSeatsBtn().vm.$emit('click');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'duo_pro_purchase_seats',
      });
    });
  });
});
