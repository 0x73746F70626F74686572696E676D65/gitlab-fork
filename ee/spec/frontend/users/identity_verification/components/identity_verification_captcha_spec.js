import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import PhoneVerificationArkoseApp from 'ee/arkose_labs/components/phone_verification_arkose_app.vue';
import ReCaptcha from '~/captcha/captcha_modal.vue';
import IdentityVerificationCaptcha from 'ee/users/identity_verification/components/identity_verification_captcha.vue';

describe('Identity Verification Captcha component', () => {
  let wrapper;

  const MOCK_ARKOSE_PUBLIC_KEY = 'arkose-labs-public-api-key';
  const MOCK_ARKOSE_DOMAIN = 'client-api.arkoselabs.com';

  const findRecaptcha = () => wrapper.findComponent(ReCaptcha);
  const findArkose = () => wrapper.findComponent(PhoneVerificationArkoseApp);

  const createComponent = (provide = {}, props = {}) => {
    wrapper = shallowMount(IdentityVerificationCaptcha, {
      provide: {
        arkoseDataExchangePayload: undefined,
        arkoseConfiguration: {
          apiKey: MOCK_ARKOSE_PUBLIC_KEY,
          domain: MOCK_ARKOSE_DOMAIN,
        },
        ...provide,
      },
      propsData: {
        showArkoseChallenge: false,
        showRecaptchaChallenge: false,
        ...props,
      },
    });
  };

  describe('When component loads', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render either captcha', () => {
      expect(findRecaptcha().exists()).toBe(false);
      expect(findArkose().exists()).toBe(false);
    });
  });

  describe('when showArkoseChallenge prop is true', () => {
    beforeEach(() => {
      createComponent({ arkoseDataExchangePayload: 'payload' }, { showArkoseChallenge: true });
    });

    it('renders arkose', () => {
      expect(findArkose().exists()).toBe(true);

      expect(findArkose().props()).toMatchObject({
        publicKey: MOCK_ARKOSE_PUBLIC_KEY,
        domain: MOCK_ARKOSE_DOMAIN,
        resetSession: false,
        dataExchangePayload: 'payload',
      });
    });

    it('emits `captcha-shown` event', () => {
      expect(wrapper.emitted('captcha-shown')).toHaveLength(1);
    });

    it('emits `captcha-solved` event when `challenge-solved` event is emitted', async () => {
      findArkose().vm.$emit('challenge-solved', 'mock-arkose-token');
      await nextTick();

      expect(wrapper.emitted('captcha-solved')[0]).toEqual([
        { arkose_labs_token: 'mock-arkose-token' },
      ]);
    });

    it('when `verificationAttempts` prop is changed, it resets captcha', async () => {
      // setProps is justified here because we are testing the component's
      // reactive behavior which constitutes an exception
      // see https://docs.gitlab.com/ee/development/fe_guide/style/vue.html#setting-component-state

      await wrapper.setProps({
        verificationAttempts: 1,
      });

      expect(findArkose().props()).toMatchObject({
        resetSession: true,
      });
    });
  });

  describe('when recaptcha is enabled', () => {
    beforeEach(() => {
      window.gon.recaptcha_sitekey = 'site-key';

      createComponent(
        {},
        {
          showRecaptchaChallenge: true,
        },
      );
    });

    it('renders recaptcha', () => {
      expect(findRecaptcha().exists()).toBe(true);

      expect(findRecaptcha().props()).toMatchObject({
        needsCaptchaResponse: true,
        captchaSiteKey: 'site-key',
        showModal: false,
        resetSession: false,
      });
    });

    it('emits `captcha-shown` event', () => {
      expect(wrapper.emitted('captcha-shown')).toHaveLength(1);
    });

    it('emits `captcha-solved` event when `receivedCaptchaResponse` event is emitted', async () => {
      findRecaptcha().vm.$emit('receivedCaptchaResponse', 'mock-recaptcha-token');
      await nextTick();

      expect(wrapper.emitted('captcha-solved')[0]).toEqual([
        { 'g-recaptcha-response': 'mock-recaptcha-token' },
      ]);
    });

    it('when `verificationAttempts` prop is changed, it resets captcha', async () => {
      // setProps is justified here because we are testing the component's
      // reactive behavior which constitutes an exception
      // see https://docs.gitlab.com/ee/development/fe_guide/style/vue.html#setting-component-state

      await wrapper.setProps({
        verificationAttempts: 1,
      });

      expect(findRecaptcha().props()).toMatchObject({
        resetSession: true,
      });
    });
  });
});
