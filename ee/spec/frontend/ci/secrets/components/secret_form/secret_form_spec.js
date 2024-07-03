import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlDatepicker, GlFormInput, GlFormTextarea } from '@gitlab/ui';
import { DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import SecretPreviewModal from 'ee/ci/secrets/components/secret_form/secret_preview_modal.vue';
import { mockProjectSecret, mockSecretId } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretForm component', () => {
  let wrapper;
  let mockApollo;
  let mockCreateSecretResponse;
  const mockRouter = {
    push: jest.fn(),
    currentRoute: {},
  };

  const defaultProps = {
    areEnvironmentsLoading: false,
    environments: ['production', 'development'],
    fullPath: 'path/to/project',
    isEditing: false,
    submitButtonText: 'Add secret',
  };

  const findAddCronButton = () => wrapper.findByTestId('add-custom-rotation-button');
  const findCronField = () => wrapper.findByTestId('secret-cron');
  const findDescriptionField = () => wrapper.findByTestId('secret-description');
  const findExpirationField = () => wrapper.findComponent(GlDatepicker);
  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findKeyFieldGroup = () => wrapper.findByTestId('secret-key-field-group');
  const findKeyField = () => findKeyFieldGroup().findComponent(GlFormInput);
  const findPreviewModal = () => wrapper.findComponent(SecretPreviewModal);
  const findRotationPeriodField = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueFieldGroup = () => wrapper.findByTestId('secret-value-field-group');
  const findValueField = () => findValueFieldGroup().findComponent(GlFormTextarea);
  const findSubmitButton = () => wrapper.findByTestId('submit-form-button');

  const createComponent = ({ props, mountFn = shallowMountExtended, stubs } = {}) => {
    const mockResolvers = {
      Mutation: {
        createSecret: mockCreateSecretResponse,
      },
    };

    mockApollo = createMockApollo([], mockResolvers);

    wrapper = mountFn(SecretForm, {
      apolloProvider: mockApollo,
      mocks: {
        $router: mockRouter,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs,
    });
  };

  const today = new Date();
  const expirationDate = getDateInFuture(today, 1);

  const inputExpiration = () => {
    findExpirationField().vm.$emit('input', { endDate: '' });
    findExpirationField().vm.$emit('input', expirationDate);
  };

  const inputCron = () => {
    findRotationPeriodField().vm.$emit('click');
    findCronField().vm.$emit('input', '0 6 * * *');
    findAddCronButton().vm.$emit('click');
  };

  const inputRequiredFields = () => {
    findKeyField().vm.$emit('input', 'SECRET_KEY');
    findValueField().vm.$emit('input', 'SECRET_VALUE');
    inputExpiration();
  };

  const submitSecret = () => {
    inputRequiredFields();
    findSubmitButton().vm.$emit('click');
    findPreviewModal().vm.$emit('submit-secret');
  };

  beforeEach(() => {
    mockCreateSecretResponse = jest.fn();
  });

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all fields', () => {
      expect(findDescriptionField().exists()).toBe(true);
      expect(findExpirationField().exists()).toBe(true);
      expect(findEnvironmentsDropdown().exists()).toBe(true);
      expect(findKeyField().exists()).toBe(true);
      expect(findRotationPeriodField().exists()).toBe(true);
      expect(findValueField().exists()).toBe(true);
    });

    it('does not show preview modal by default', () => {
      expect(findPreviewModal().props('isVisible')).toBe(false);
    });

    it('sets expiration date in the future', () => {
      const expirationMinDate = findExpirationField().props('minDate').getTime();
      expect(expirationMinDate).toBeGreaterThan(today.getTime());
    });
  });

  describe('environment dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { CiEnvironmentsDropdown } });
    });

    it('sets the environment', async () => {
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('*');

      await findEnvironmentsDropdown().vm.$emit('select-environment', 'staging');

      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('staging');
    });

    it('does not require environment (shows Not Applicable option)', () => {
      expect(findEnvironmentsDropdown().props('isEnvironmentRequired')).toBe(false);
    });

    it('bubbles up the search event', async () => {
      await findEnvironmentsDropdown().vm.$emit('search-environment-scope', 'dev');

      expect(wrapper.emitted('search-environment')).toEqual([['dev']]);
    });
  });

  describe('rotation period field', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows default toggle text', () => {
      expect(findRotationPeriodField().props('toggleText')).toBe('Select a rotation interval');
    });

    it('can select predefined rotation periods and renders the correct toggle text', async () => {
      findRotationPeriodField().vm.$emit('click');
      findRotationPeriodField().vm.$emit('select', '14');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('Every 2 weeks');
    });

    it('can set custom cron', async () => {
      findRotationPeriodField().vm.$emit('click');
      findCronField().vm.$emit('input', '0 6 * * *');
      findAddCronButton().vm.$emit('click');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('0 6 * * *');
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates key field', async () => {
      expect(findKeyField().attributes('state')).toBe('true');

      findKeyField().vm.$emit('input', '');
      await nextTick();

      expect(findKeyField().attributes('state')).toBeUndefined();
      expect(findKeyFieldGroup().attributes('invalid-feedback')).toBe('This field is required');

      findKeyField().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findKeyField().attributes('state')).toBe('true');
    });

    it('validates value field', async () => {
      expect(findValueField().attributes('state')).toBe('true');

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueField().attributes('state')).toBeUndefined();
      expect(findValueFieldGroup().attributes('invalid-feedback')).toBe('This field is required');

      findValueField().vm.$emit('input', 'SECRET_VALUE');
      await nextTick();

      expect(findValueField().attributes('state')).toBe('true');
    });

    it('submit button is enabled when required fields have input', async () => {
      expect(findSubmitButton().props('disabled')).toBe(true);

      inputRequiredFields();
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });
  });

  describe('preview modal', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
      inputRequiredFields();
    });

    it('submit button opens preview modal', async () => {
      expect(findPreviewModal().props('isVisible')).toBe(false);

      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findPreviewModal().props('isVisible')).toBe(true);
    });

    it('passes the correct props', async () => {
      findDescriptionField().vm.$emit('input', 'This is a secret.');
      inputCron();

      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findPreviewModal().props()).toMatchObject({
        description: 'This is a secret.',
        environment: '*',
        expiration: expirationDate,
        isEditing: defaultProps.isEditing,
        rotationPeriod: '0 6 * * *',
        secretKey: 'SECRET_KEY',
      });
    });

    it('hides modal when hide-preview-modal event is emitted', async () => {
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findPreviewModal().props('isVisible')).toBe(true);

      await findPreviewModal().vm.$emit('hide-preview-modal');

      expect(findPreviewModal().props('isVisible')).toBe(false);
    });
  });

  describe('form submission', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('while submitting', async () => {
      expect(findSubmitButton().props('loading')).toBe(false);

      submitSecret();
      await nextTick();

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(mockProjectSecret());
        createComponent({ mountFn: mountExtended });
      });

      it('redirects to the secret details page', async () => {
        submitSecret();
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { id: mockSecretId },
        });
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(
          mockProjectSecret({ errors: ['This secret is invalid.'] }),
        );
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        submitSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({ message: 'This secret is invalid.' });
      });
    });

    describe('when submission fails', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockRejectedValue(new Error());
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        submitSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong on our end. Please try again.',
        });
      });
    });
  });
});
