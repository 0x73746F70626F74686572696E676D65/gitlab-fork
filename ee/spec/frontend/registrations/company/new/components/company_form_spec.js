import { GlButton, GlForm, GlFormText } from '@gitlab/ui';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trackCompanyForm } from 'ee/google_tag_manager';

const SUBMIT_PATH = '_submit_path_';

jest.mock('ee/google_tag_manager');

describe('CompanyForm', () => {
  let wrapper;

  const createComponent = (provideData = {}) => {
    return shallowMountExtended(CompanyForm, {
      provide: {
        submitPath: SUBMIT_PATH,
        user: {
          firstName: 'Joe',
          lastName: 'Doe',
        },
        ...provideData,
      },
    });
  };

  const findDescription = () => wrapper.findComponent(GlFormText);
  const findSubmitButton = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findFooterDescriptionText = () => wrapper.findByTestId('footer_description_text');

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      testid
      ${'first_name'}
      ${'last_name'}
      ${'company_name'}
      ${'company_size'}
      ${'country'}
      ${'phone_number'}
      ${'website_url'}
    `('has the correct form input in the form content', ({ testid }) => {
      expect(findFormInput(testid).exists()).toBe(true);
    });
  });

  describe('when initialTrial is true', () => {
    beforeEach(() => {
      wrapper = createComponent({ initialTrial: true });
    });

    it('displays correct description text', () => {
      expect(findDescription().text()).toBe(
        'To activate your trial, we need additional details from you.',
      );
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue');
    });

    it('does not display footer text', () => {
      expect(findFooterDescriptionText().text()).toBe('');
    });
  });

  describe('when initialTrial is false', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('displays correct description text', () => {
      expect(findDescription().text()).toBe(
        'To complete registration, we need additional details from you.',
      );
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Start free GitLab Ultimate trial');
    });

    it('displays correct footer text', () => {
      expect(findFooterDescriptionText().exists()).toBe(true);
      expect(findFooterDescriptionText().text()).toBe(
        "You don't need a credit card to start a trial. After the 30-day trial period, your account automatically becomes a GitLab Free account. You can use your GitLab Free account forever, or upgrade to a paid tier.",
      );
    });
  });

  describe('submitting', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('submits the form when button is clicked', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
    });

    it('displays form with correct action', () => {
      expect(findForm().attributes('action')).toBe(SUBMIT_PATH);
    });

    it('tracks form submission', () => {
      findForm().vm.$emit('submit');

      expect(trackCompanyForm).toHaveBeenCalledWith('ultimate_trial');
    });
  });
});
