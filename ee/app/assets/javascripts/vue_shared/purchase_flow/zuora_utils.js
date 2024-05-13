import get from 'lodash/get';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

/**
 * Receives an error message from Zuora and returns an extracted Stripe code if found, otherwise null.
 *
 * Zuora documentation:
 * https://knowledgecenter.zuora.com/Billing/Billing_and_Payments/LA_Hosted_Payment_Pages/B_Payment_Pages_2.0/N_Error_Handling_for_Payment_Pages_2.0/Customize_Error_Messages_for_Payment_Pages_2.0#Define_Custom_Error_Message_Handling_Function
 * https://knowledgecenter.zuora.com/Billing/Billing_and_Payments/LA_Hosted_Payment_Pages/B_Payment_Pages_2.0/H_Integrate_Payment_Pages_2.0/A_Advanced_Integration_of_Payment_Pages_2.0#Customize_Error_Messages_in_Advanced_Integration
 *
 * Any Stripe error will contain an {error_type}, optionally followed by {decline_code}, which is followed by an {error_code} of the format:
 * "[{error_type}/({decline_code}/){error_code}]"
 *
 * Examples of Stripe errors:
 * [card_error/invalid_cvc]
 * [card_error/authentication_required/authentication_required]
 * [invalid_request_error/setup_intent_authentication_failure]
 *
 * Stripe documentation:
 * https://docs.stripe.com/api/errors#errors-type
 * https://docs.stripe.com/declines/codes#stripe-decline-codes
 * https://docs.stripe.com/api/setup_attempts/object#setup_attempt_object-setup_error
 *
 * @param {String} message
 * @returns extracted Stripe error code, or null
 */
export function extractErrorCode(message) {
  try {
    const results = message?.match(/\[\w+_error\/.*\]/);
    const extractedCode = get(results, '[0]');
    if (!extractedCode) {
      return null;
    }

    return extractedCode;
  } catch (error) {
    // Log error if extraction fails for unknown reasons
    Sentry.captureException(error);
    return null;
  }
}
