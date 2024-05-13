import { get } from 'lodash';
import * as zuoraUtils from 'ee/vue_shared/purchase_flow/zuora_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('lodash/get', () => jest.fn((fn) => fn));
const lodash = jest.requireActual('lodash');

describe('Zuora utilities', () => {
  beforeEach(() => {
    get.mockImplementation(lodash.get);
  });

  describe('extractErrorCode', () => {
    describe.each([
      { message: null, expected: null },
      { message: undefined, expected: null },
      { message: '', expected: null },
      { message: '[xy z_error/]', expected: null },
      { message: '[card_error/]', expected: '[card_error/]' },
      { message: '[abc_error/]', expected: '[abc_error/]' },
      {
        message: '[GatewayTransactionError] Error:[card_error/abc/]xyz',
        expected: '[card_error/abc/]',
      },
    ])('for $message", returns $expected', ({ message, expected }) => {
      it('returns empty string if no perPage parameter is provided', () => {
        expect(zuoraUtils.extractErrorCode(message)).toEqual(expected);
      });
    });

    describe('when erroring', () => {
      beforeEach(() => {
        Sentry.captureException = jest.fn();
        get.mockImplementation(() => {
          throw new Error('An error occured');
        });
      });

      it('returns empty string if no perPage parameter is provided', () => {
        expect(zuoraUtils.extractErrorCode('[card_error/]')).toEqual(null);
      });

      it('sends error to Senty', () => {
        zuoraUtils.extractErrorCode('[card_error/]');
        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('An error occured'));
      });
    });
  });
});
