import { GlModal, GlFormTextarea } from '@gitlab/ui';
import { kebabCase, pick } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createWrapper } from '@vue/test-utils';
import { sprintf } from '~/locale';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking } from 'helpers/tracking_helper';
import HandRaiseLeadModal from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  PQL_MODAL_PRIMARY,
  PQL_MODAL_CANCEL,
  PQL_MODAL_HEADER_TEXT,
  PQL_MODAL_FOOTER_TEXT,
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
} from 'ee/hand_raise_leads/hand_raise_lead/constants';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import eventHub from 'ee/hand_raise_leads/hand_raise_lead/event_hub';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import {
  FORM_DATA,
  USER,
  CREATE_HAND_RAISE_LEAD_PATH,
  GLM_CONTENT,
  PRODUCT_INTERACTION,
} from './mock_data';

Vue.use(VueApollo);

describe('HandRaiseLeadModal', () => {
  let wrapper;
  let trackingSpy;

  const createComponent = (props = {}) => {
    return shallowMountExtended(HandRaiseLeadModal, {
      propsData: {
        submitPath: CREATE_HAND_RAISE_LEAD_PATH,
        user: USER,
        ...props,
      },
    });
  };

  const expectTracking = (action) =>
    expect(trackingSpy).toHaveBeenCalledWith(undefined, action, {
      label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
    });

  const findModal = () => wrapper.findComponent(GlModal);
  const triggerOpenModal = async ({
    productInteraction = PRODUCT_INTERACTION,
    ctaTracking = {},
    glmContent = GLM_CONTENT,
  } = {}) => {
    eventHub.$emit('openModal', { productInteraction, ctaTracking, glmContent });
    await nextTick();
  };
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findCountryOrRegionSelector = () => wrapper.findComponent(CountryOrRegionSelector);
  const submitForm = () => findModal().vm.$emit('primary');

  const fillForm = ({ stateRequired = false, comment = '' } = {}) => {
    const { country, state } = FORM_DATA;
    const inputForms = pick(FORM_DATA, [
      'firstName',
      'lastName',
      'companyName',
      'companySize',
      'phoneNumber',
    ]);

    Object.entries(inputForms).forEach(([key, value]) => {
      wrapper.findByTestId(kebabCase(key)).vm.$emit('input', value);
    });

    findCountryOrRegionSelector().vm.$emit('change', {
      country,
      state,
      stateRequired,
    });

    wrapper.findComponent(GlFormTextarea).vm.$emit('input', comment);

    return nextTick();
  };

  describe('rendering', () => {
    let rootWrapper;

    beforeEach(() => {
      wrapper = createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      rootWrapper = createWrapper(wrapper.vm.$root);
    });

    it('has the default injected values', () => {
      const formInputValues = [
        { id: 'first-name', value: 'Joe' },
        { id: 'last-name', value: 'Doe' },
        { id: 'company-name', value: 'ACME' },
        { id: 'phone-number', value: '' },
        { id: 'company-size', value: undefined },
      ];

      formInputValues.forEach(({ id, value }) => {
        expect(findFormInput(id).attributes('value')).toBe(value);
      });

      expect(findFormInput('state').exists()).toBe(false);
    });

    it('has the correct form input in the form content', () => {
      const visibleFields = [
        'first-name',
        'last-name',
        'company-name',
        'company-size',
        'phone-number',
      ];

      visibleFields.forEach((f) => expect(wrapper.findByTestId(f).exists()).toBe(true));

      expect(wrapper.findByTestId('state').exists()).toBe(false);
    });

    it('has the correct text in the modal content', () => {
      expect(findModal().text()).toContain(sprintf(PQL_MODAL_HEADER_TEXT, { userName: 'joe' }));
      expect(findModal().text()).toContain(PQL_MODAL_FOOTER_TEXT);
    });

    it('has the correct modal props', () => {
      expect(findModal().props('actionPrimary')).toStrictEqual({
        text: PQL_MODAL_PRIMARY,
        attributes: { variant: 'confirm', disabled: true },
      });
      expect(findModal().props('actionCancel')).toStrictEqual({
        text: PQL_MODAL_CANCEL,
      });
    });

    it('tracks modal view', async () => {
      await triggerOpenModal();

      expectTracking('hand_raise_form_viewed');
    });

    it('opens the modal', async () => {
      await triggerOpenModal();

      expect(rootWrapper.emitted(BV_SHOW_MODAL)).toHaveLength(1);
    });
  });

  describe('submit button', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('becomes enabled when required info is there', async () => {
      await fillForm();

      expect(findModal().props('actionPrimary')).toStrictEqual({
        text: PQL_MODAL_PRIMARY,
        attributes: { variant: 'confirm', disabled: false },
      });
    });
  });

  describe('form', () => {
    beforeEach(async () => {
      wrapper = createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      await fillForm({ stateRequired: true, comment: 'comment' });
    });

    describe('successful submission', () => {
      beforeEach(async () => {
        jest.spyOn(SubscriptionsApi, 'sendHandRaiseLead').mockResolvedValue();

        await triggerOpenModal();

        submitForm();
      });

      it('primary submits the valid form', () => {
        expect(SubscriptionsApi.sendHandRaiseLead).toHaveBeenCalledWith(
          '/-/subscriptions/hand_raise_leads',
          {
            namespaceId: 1,
            comment: 'comment',
            glmContent: GLM_CONTENT,
            productInteraction: PRODUCT_INTERACTION,
            ...FORM_DATA,
          },
        );
      });

      it('clears the form after submission', () => {
        ['first-name', 'last-name', 'company-name', 'phone-number'].forEach((f) =>
          expect(wrapper.findByTestId(f).attributes('value')).toBe(''),
        );

        expect(wrapper.findByTestId('company-size').attributes('value')).toBe(undefined);
        expect(findCountryOrRegionSelector().props()).toMatchObject({
          country: '',
          state: '',
          required: false,
        });
      });

      it('tracks successful submission', () => {
        expectTracking('hand_raise_submit_form_succeeded');
      });
    });

    describe('failed submission', () => {
      beforeEach(() => {
        jest.spyOn(SubscriptionsApi, 'sendHandRaiseLead').mockRejectedValue();

        submitForm();
      });

      it('tracks failed submission', () => {
        expectTracking('hand_raise_submit_form_failed');
      });
    });

    describe('form cancel', () => {
      beforeEach(() => {
        findModal().vm.$emit('cancel');
      });

      it('tracks cancel', () => {
        expectTracking('hand_raise_form_canceled');
      });
    });
  });
});
