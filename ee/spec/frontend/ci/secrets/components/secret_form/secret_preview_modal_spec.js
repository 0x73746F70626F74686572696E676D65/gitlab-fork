import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretPreviewModal from 'ee/ci/secrets/components/secret_form/secret_preview_modal.vue';

describe('SecretPreviewModal component', () => {
  let wrapper;

  const defaultProps = {
    createdAt: 1708902979844,
    description: 'This is a secret.',
    environment: 'staging/*',
    expiration: new Date('2024-03-01'),
    isEditing: false,
    isVisible: true,
    secretKey: 'SECRET_KEY',
    rotationPeriod: 'Every 2 weeks',
  };

  const findCreatedAt = () => wrapper.findByTestId('secret-preview-created-at');
  const findDescription = () => wrapper.findByTestId('secret-preview-description');
  const findEnvironment = () => wrapper.findByTestId('secret-preview-environment');
  const findExpiration = () => wrapper.findByTestId('secret-preview-expiration');
  const findModal = () => wrapper.findComponent(GlModal);
  const findRotationPeriod = () => wrapper.findByTestId('secret-preview-rotation-period');

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(SecretPreviewModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders and formats form information', () => {
      expect(findModal().props('title')).toBe('Preview for SECRET_KEY');
      expect(findCreatedAt().text()).toBe('February 25, 2024 at 11:16:19 PM GMT');
      expect(findDescription().text()).toBe(defaultProps.description);
      expect(findEnvironment().text()).toBe(defaultProps.environment);
      expect(findExpiration().text()).toBe('March 1, 2024 at 12:00:00 AM GMT');
      expect(findRotationPeriod().text()).toBe(defaultProps.rotationPeriod);
    });
  });

  describe('validations', () => {
    beforeEach(() => {
      createComponent({
        props: {
          expiration: null,
        },
      });
    });

    it('renders None when there is no expiration date', () => {
      expect(findExpiration().text()).toBe('None');
    });
  });

  describe('when creating', () => {
    beforeEach(() => {
      createComponent({ props: { isEditing: false } });
    });

    it('renders the correct submit button text', () => {
      expect(findModal().props('actionPrimary').text).toBe('Add secret');
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createComponent({ props: { isEditing: true } });
    });

    it('renders the correct submit button text', () => {
      expect(findModal().props('actionPrimary').text).toBe('Save changes');
    });
  });

  describe('emitting events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('bubbles up form submit event', () => {
      expect(wrapper.emitted('submit-secret')).toBeUndefined();

      findModal().vm.$emit('primary');

      expect(wrapper.emitted('submit-secret')).toHaveLength(1);
    });

    it('bubbles up hide event when visibility changes', () => {
      expect(wrapper.emitted('hide-preview-modal')).toBeUndefined();

      findModal().vm.$emit('change');

      expect(wrapper.emitted('hide-preview-modal')).toHaveLength(1);
    });

    it('bubbles up hide event when canceled', () => {
      expect(wrapper.emitted('hide-preview-modal')).toBeUndefined();

      findModal().vm.$emit('canceled');

      expect(wrapper.emitted('hide-preview-modal')).toHaveLength(1);
    });
  });
});
