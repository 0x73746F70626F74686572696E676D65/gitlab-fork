import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HandRaiseLeadModal from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import HandRaiseLead from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead.vue';
import { PQL_BUTTON_TEXT } from 'ee/hand_raise_leads/hand_raise_lead/constants';
import { USER, CREATE_HAND_RAISE_LEAD_PATH, GLM_CONTENT, PRODUCT_INTERACTION } from './mock_data';

describe('HandRaiseLead', () => {
  let wrapper;
  const ctaTracking = { action: '_action_', label: '_label_' };

  const createComponent = () => {
    return shallowMountExtended(HandRaiseLead, {
      provide: {
        createHandRaiseLeadPath: CREATE_HAND_RAISE_LEAD_PATH,
        user: USER,
        ctaTracking,
        glmContent: GLM_CONTENT,
        productInteraction: PRODUCT_INTERACTION,
      },
    });
  };

  const findButton = () => wrapper.findComponent(HandRaiseLeadButton);
  const findModal = () => wrapper.findComponent(HandRaiseLeadModal);

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('rendering', () => {
    it('renders the hand raise lead button', () => {
      expect(findButton().exists()).toBe(true);
    });

    it('renders the hand raise lead modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('has the correct button props', () => {
      expect(findButton().props('modalId').startsWith('hand-raise-lead-modal-')).toBe(true);
      expect(findButton().props('buttonAttributes')).toStrictEqual({});
      expect(findButton().props('buttonText')).toStrictEqual(PQL_BUTTON_TEXT);
      expect(findButton().props('glmContent')).toStrictEqual(GLM_CONTENT);
      expect(findButton().props('productInteraction')).toStrictEqual(PRODUCT_INTERACTION);
      expect(findButton().props('ctaTracking')).toStrictEqual(ctaTracking);
      expect(findButton().props('isLoading')).toBe(false);
    });

    it('has the correct modal props', () => {
      expect(findModal().props('user')).toStrictEqual(USER);
      expect(findModal().props('submitPath')).toStrictEqual(CREATE_HAND_RAISE_LEAD_PATH);
      expect(findModal().props('modalId').startsWith('hand-raise-lead-modal-')).toBe(true);
    });
  });

  describe('loading', () => {
    it('changes the state of loading', async () => {
      findModal().vm.$emit('loading', true);
      await nextTick();

      expect(findButton().props('isLoading')).toBe(true);

      findModal().vm.$emit('loading', false);
      await nextTick();

      expect(findButton().props('isLoading')).toBe(false);
    });
  });
});
