import { GlButton, GlForm, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import TrialCreateLeadForm from 'ee/trials/components/trial_create_lead_form.vue';
import CountryOrRegionSelector from 'jh_else_ee/trials/components/country_or_region_selector.vue';
import {
  GENERIC_TRIAL_FORM_SUBMIT_TEXT,
  TRIAL_TERMS_TEXT,
  ULTIMATE_TRIAL_FORM_SUBMIT_TEXT,
  DUO_PRO_TRIAL_VARIANT,
} from 'ee/trials/constants';
import { trackSaasTrialSubmit } from 'ee/google_tag_manager';
import { FORM_DATA, SUBMIT_PATH, GTM_SUBMIT_EVENT_LABEL } from './mock_data';

jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('TrialCreateLeadForm', () => {
  let wrapper;

  const createComponent = ({
    mountFunction = shallowMountExtended,
    provide = { trialVariant: undefined },
  } = {}) =>
    mountFunction(TrialCreateLeadForm, {
      provide: {
        submitPath: SUBMIT_PATH,
        user: FORM_DATA,
        gtmSubmitEventLabel: GTM_SUBMIT_EVENT_LABEL,
        ...provide,
      },
      stubs: {
        CountryOrRegionSelector: stubComponent(CountryOrRegionSelector, {
          template: `<div></div>`,
        }),
      },
    });

  const findForm = () => wrapper.findComponent(GlForm);
  const findButton = () => wrapper.findComponent(GlButton);
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findTermsSprintf = () => wrapper.findComponent(GlSprintf);

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      testid                     | value
      ${'first-name-field'}      | ${'Joe'}
      ${'last-name-field'}       | ${'Doe'}
      ${'company-name-field'}    | ${'ACME'}
      ${'phone-number-field'}    | ${'192919'}
      ${'company-size-dropdown'} | ${'1-99'}
    `('has the default injected value for $testid', ({ testid, value }) => {
      expect(findFormInput(testid).attributes('value')).toBe(value);
    });

    it('has the correct form input in the form content', () => {
      const visibleFields = [
        'first-name-field',
        'last-name-field',
        'company-name-field',
        'company-size-dropdown',
        'phone-number-field',
      ];

      visibleFields.forEach((f) => expect(findFormInput(f).exists()).toBe(true));
    });

    it('has correct terms and conditions content', () => {
      expect(findTermsSprintf().attributes('message')).toBe(TRIAL_TERMS_TEXT);
    });
  });

  it('has the "Start free GitLab Ultimate trial" text on the submit button', () => {
    wrapper = createComponent();

    expect(findButton().text()).toBe(ULTIMATE_TRIAL_FORM_SUBMIT_TEXT);
  });

  it('has the "Continue" text on the submit button when for other trial variants', () => {
    wrapper = createComponent({ provide: { trialVariant: DUO_PRO_TRIAL_VARIANT } });

    expect(findButton().text()).toBe(GENERIC_TRIAL_FORM_SUBMIT_TEXT);
  });

  describe('submitting', () => {
    beforeEach(() => {
      wrapper = createComponent({ mountFunction: mountExtended });
    });

    it('tracks the saas Trial submitting', () => {
      findForm().trigger('submit');

      expect(trackSaasTrialSubmit).toHaveBeenCalledWith(GTM_SUBMIT_EVENT_LABEL);
    });

    it.each`
      value                    | result
      ${null}                  | ${false}
      ${'+1 (121) 22-12-23'}   | ${false}
      ${'+12190AX '}           | ${false}
      ${'Tel:129120'}          | ${false}
      ${'11290+12'}            | ${false}
      ${FORM_DATA.phoneNumber} | ${true}
    `('validates the phone number with value of `$value`', ({ value, result }) => {
      expect(findFormInput('phone-number-field').exists()).toBe(true);

      findFormInput('phone-number-field').setValue(value);

      findForm().trigger('submit');

      expect(findFormInput('phone-number-field').element.checkValidity()).toBe(result);
    });
  });
});
