import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import { salesLink } from 'ee/usage_quotas/code_suggestions/constants';
import HandRaiseLead from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead.vue';

describe('Code Suggestions Intro', () => {
  let wrapper;
  const emptyState = () => wrapper.findComponent(GlEmptyState);
  const handRaiseLeadButton = () => wrapper.findComponent(HandRaiseLead);

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
      const defaultButton = wrapper.find(`a[href="${salesLink}"`);
      expect(emptyState().exists()).toBe(true);
      expect(handRaiseLeadButton().exists()).toBe(true);
      expect(defaultButton.exists()).toBe(false);
    });
  });
});
