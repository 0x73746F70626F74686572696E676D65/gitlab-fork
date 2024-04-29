import { nextTick } from 'vue';
import { createAlert } from '~/alert';
import DomElementListener from '~/vue_shared/components/dom_element_listener.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { logError } from '~/lib/logger';
import SignUpArkoseApp from 'ee/arkose_labs/components/sign_up_arkose_app.vue';
import { initArkoseLabsChallenge } from 'ee/arkose_labs/init_arkose_labs';
import {
  VERIFICATION_LOADING_MESSAGE,
  VERIFICATION_REQUIRED_MESSAGE,
  VERIFICATION_TOKEN_INPUT_NAME,
} from 'ee/arkose_labs/constants';

jest.mock('~/alert');
jest.mock('~/lib/logger');
jest.mock('ee/arkose_labs/init_arkose_labs');
let onShown;
let onCompleted;
const mockDataExchangePayload = 'fakeDataExchangePayload';
initArkoseLabsChallenge.mockImplementation(({ config }) => {
  onShown = config.onShown;
  onCompleted = config.onCompleted;
});

const MOCK_ARKOSE_RESPONSE = { token: 'verification-token' };
const MOCK_PUBLIC_KEY = 'arkose-labs-public-api-key';
const MOCK_DOMAIN = 'client-api.arkoselabs.com';

describe('SignUpArkoseApp', () => {
  let wrapper;

  const findChallengeContainer = () => wrapper.findByTestId('arkose-labs-challenge');
  const findArkoseLabsVerificationTokenInput = () =>
    wrapper.find(`input[name="${VERIFICATION_TOKEN_INPUT_NAME}"]`);

  const submitForm = async (event) => {
    wrapper.findComponent(DomElementListener).vm.$emit('submit', event);
    await nextTick();
  };

  const createComponent = ({ props } = { props: {} }) => {
    wrapper = mountExtended(SignUpArkoseApp, {
      propsData: {
        publicKey: MOCK_PUBLIC_KEY,
        domain: MOCK_DOMAIN,
        dataExchangePayload: mockDataExchangePayload,
        formSelector: 'dummy',
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper?.destroy();
  });

  beforeEach(() => {
    createComponent();
  });

  it('initializes Arkose Labs challenge', () => {
    expect(initArkoseLabsChallenge).toHaveBeenCalledWith({
      publicKey: MOCK_PUBLIC_KEY,
      domain: MOCK_DOMAIN,
      dataExchangePayload: mockDataExchangePayload,
      config: expect.objectContaining({
        onShown: expect.any(Function),
        onCompleted: expect.any(Function),
      }),
    });
  });

  it('creates a hidden input for the verification token', () => {
    const input = findArkoseLabsVerificationTokenInput();

    expect(input.exists()).toBe(true);
    expect(input.element.value).toBe('');
  });

  it('shows the challenge container when Arkose Labs calls `onShown`', async () => {
    expect(findChallengeContainer().isVisible()).toBe(false);

    onShown();
    await nextTick();

    expect(findChallengeContainer().isVisible()).toBe(true);
  });

  describe('when Arkose Labs calls `onCompleted`', () => {
    beforeEach(() => {
      onCompleted(MOCK_ARKOSE_RESPONSE);
    });

    it("sets the verification token input's value", () => {
      expect(findArkoseLabsVerificationTokenInput().element.value).toBe(MOCK_ARKOSE_RESPONSE.token);
    });
  });

  describe('when form is submitted', () => {
    let mockSubmitEvent;

    beforeEach(() => {
      mockSubmitEvent = { preventDefault: jest.fn(), stopPropagation: jest.fn() };
    });

    describe('when challenge was not completed', () => {
      beforeEach(async () => {
        onShown();

        await submitForm(mockSubmitEvent);
      });

      it('shows verification required error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: VERIFICATION_REQUIRED_MESSAGE,
        });
      });

      it('stops the submit event', () => {
        expect(mockSubmitEvent.preventDefault).toHaveBeenCalledTimes(1);
        expect(mockSubmitEvent.stopPropagation).toHaveBeenCalledTimes(1);
      });
    });

    describe('when challenge was completed', () => {
      beforeEach(async () => {
        onShown();
        onCompleted(MOCK_ARKOSE_RESPONSE);

        await nextTick();

        submitForm(mockSubmitEvent);
      });

      it('does not show verification required error message', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('does not stop the submit event', () => {
        expect(mockSubmitEvent.preventDefault).not.toHaveBeenCalled();
        expect(mockSubmitEvent.stopPropagation).not.toHaveBeenCalled();
      });
    });

    describe('when challenge has not been shown yet (loading)', () => {
      beforeEach(async () => {
        await submitForm(mockSubmitEvent);
      });

      it('shows verification loading message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: VERIFICATION_LOADING_MESSAGE,
        });
      });
    });

    describe('when challenge fails to load', () => {
      const arkoseError = new Error();

      beforeEach(() => {
        initArkoseLabsChallenge.mockImplementation(() => {
          throw arkoseError;
        });

        createComponent();
      });

      it('logs the error', () => {
        expect(logError).toHaveBeenCalledWith('ArkoseLabs initialization error', arkoseError);
      });

      it('does not stop the submit event', () => {
        submitForm(mockSubmitEvent);

        expect(mockSubmitEvent.preventDefault).not.toHaveBeenCalled();
        expect(mockSubmitEvent.stopPropagation).not.toHaveBeenCalled();
      });
    });
  });
});
