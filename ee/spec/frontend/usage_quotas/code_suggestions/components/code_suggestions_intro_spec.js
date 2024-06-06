import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

describe('Code Suggestions Intro', () => {
  let wrapper;
  const emptyState = () => wrapper.findComponent(GlEmptyState);
  const handRaiseLeadButton = () => wrapper.findComponent(HandRaiseLeadButton);

  const createComponent = (provideProps = {}) => {
    wrapper = shallowMount(CodeSuggestionsIntro, {
      mocks: { GlEmptyState },
      provide: {
        ...provideProps,
      },
    });
  };

  describe('when rendering', () => {
    beforeEach(() => {
      return createComponent({ createHandRaiseLeadPath: 'some-path' });
    });

    it('renders gl-empty-state component with hand raise lead', () => {
      const buttonProps = {
        buttonAttributes: {
          variant: 'confirm',
          category: 'tertiary',
          class: 'gl-sm-w-auto gl-w-full gl-sm-ml-3 gl-sm-mt-0 gl-mt-3',
          'data-testid': 'code-suggestions-hand-raise-lead-button',
        },
        glmContent: 'code-suggestions',
        buttonText: 'Contact sales',
        productInteraction: 'Requested Contact-Duo Pro Add-On',
        ctaTracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form',
        },
      };

      expect(emptyState().exists()).toBe(true);
      expect(handRaiseLeadButton().exists()).toBe(true);
      expect(handRaiseLeadButton().props()).toEqual(buttonProps);
    });
  });
});
